// See pp_llm.h for the contract. Implementation notes:
// - One generation at a time per handle (atomic busy flag; second call fails
//   fast instead of queueing — the UI already serializes sends).
// - The KV cache is cleared before every generation: the app sends the full
//   chat history each time, so each run is a clean prompt. Simple and stateless
//   beats clever and corrupt in an emergency tool.
// - Every emitted piece is strdup'd; the receiver frees it. This survives the
//   asynchronous hop into Dart's NativeCallable.listener.
#include "pp_llm.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#include "llama.h"

namespace {

std::string g_last_error;

struct PpLlm {
    llama_model * model = nullptr;
    llama_context * ctx = nullptr;
    const llama_vocab * vocab = nullptr;
    int32_t n_ctx = 0;
    std::atomic<bool> busy{false};
    std::atomic<bool> cancel{false};
    std::thread worker;

    ~PpLlm() {
        cancel.store(true);
        if (worker.joinable()) worker.join();
        if (ctx) llama_free(ctx);
        if (model) llama_model_free(model);
    }
};

void ensure_backend() {
    static bool once = [] {
        llama_backend_init();
        return true;
    }();
    (void) once;
}

} // namespace

extern "C" {

void * ppllm_load(const char * model_path, int32_t n_ctx, int32_t n_gpu_layers) {
    ensure_backend();
    auto * h = new PpLlm();

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = n_gpu_layers;
#if defined(TARGET_OS_SIMULATOR) && TARGET_OS_SIMULATOR
    // The iOS Simulator's Metal stack miscompiles ggml kernels (output turns
    // to garbage); CPU is correct there. Real iPhones get full Metal.
    mparams.n_gpu_layers = 0;
#endif
    h->model = llama_model_load_from_file(model_path, mparams);
    if (!h->model) {
        g_last_error = std::string("no se pudo cargar el modelo: ") + model_path;
        delete h;
        return nullptr;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = n_ctx > 0 ? (uint32_t) n_ctx : 4096;
    cparams.n_batch = 512;
    h->ctx = llama_init_from_model(h->model, cparams);
    if (!h->ctx) {
        g_last_error = "no se pudo crear el contexto de inferencia";
        delete h;
        return nullptr;
    }

    h->vocab = llama_model_get_vocab(h->model);
    h->n_ctx = (int32_t) llama_n_ctx(h->ctx);
    return h;
}

char * ppllm_apply_template(void * handle, const char ** roles,
                            const char ** contents, int32_t n_msgs) {
    auto * h = (PpLlm *) handle;
    if (!h || n_msgs <= 0) return nullptr;

    std::vector<llama_chat_message> chat(n_msgs);
    size_t total = 0;
    for (int32_t i = 0; i < n_msgs; i++) {
        chat[i].role = roles[i];
        chat[i].content = contents[i];
        total += strlen(contents[i]) + strlen(roles[i]) + 16;
    }

    const char * tmpl = llama_model_chat_template(h->model, nullptr);
    // Models without an embedded template still deserve a sane prompt.
    if (!tmpl) tmpl = "chatml";

    std::vector<char> buf(total * 2 + 256);
    int32_t n = llama_chat_apply_template(tmpl, chat.data(), chat.size(), true,
                                          buf.data(), (int32_t) buf.size());
    if (n < 0) {
        g_last_error = "la plantilla de chat del modelo falló";
        return nullptr;
    }
    if ((size_t) n >= buf.size()) {
        buf.resize(n + 1);
        n = llama_chat_apply_template(tmpl, chat.data(), chat.size(), true,
                                      buf.data(), (int32_t) buf.size());
        if (n < 0) return nullptr;
    }
    char * out = (char *) malloc(n + 1);
    memcpy(out, buf.data(), n);
    out[n] = '\0';
    return out;
}

int32_t ppllm_generate(void * handle, const char * prompt, int32_t max_tokens,
                       float temp, ppllm_token_cb cb, void * user) {
    auto * h = (PpLlm *) handle;
    if (!h || !prompt || !cb) return -1;

    bool expected = false;
    if (!h->busy.compare_exchange_strong(expected, true)) return -1;
    if (h->worker.joinable()) h->worker.join();
    h->cancel.store(false);

    std::string prompt_copy(prompt);
    h->worker = std::thread([h, prompt_copy, max_tokens, temp, cb, user] {
        // Tokenize (two-pass: size then fill).
        int32_t n_prompt = -llama_tokenize(h->vocab, prompt_copy.c_str(),
                                           (int32_t) prompt_copy.size(),
                                           nullptr, 0, true, true);
        std::vector<llama_token> tokens(n_prompt > 0 ? n_prompt : 0);
        if (n_prompt <= 0 ||
            llama_tokenize(h->vocab, prompt_copy.c_str(),
                           (int32_t) prompt_copy.size(), tokens.data(),
                           n_prompt, true, true) < 0) {
            cb(nullptr, user);
            h->busy.store(false);
            return;
        }

        // Keep room to answer: if the chat outgrew the context, drop the
        // oldest tokens (the app resends full history every turn anyway).
        const int32_t budget = h->n_ctx - (max_tokens > 0 ? max_tokens : 256) - 8;
        if ((int32_t) tokens.size() > budget && budget > 0) {
            tokens.erase(tokens.begin(),
                         tokens.end() - budget);
        }

        // Fresh run: clear whatever a previous generation left in the cache.
        llama_memory_clear(llama_get_memory(h->ctx), true);

        // Sampler: min-p + temperature, or greedy when temp <= 0.
        llama_sampler * smpl =
            llama_sampler_chain_init(llama_sampler_chain_default_params());
        if (temp > 0.0f) {
            llama_sampler_chain_add(smpl, llama_sampler_init_min_p(0.05f, 1));
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(temp));
            llama_sampler_chain_add(
                smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
        } else {
            llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
        }

        // Decode the prompt in n_batch-sized chunks.
        const int32_t n_batch = 512;
        bool failed = false;
        for (size_t i = 0; i < tokens.size() && !failed; i += n_batch) {
            if (h->cancel.load()) { failed = true; break; }
            const int32_t n =
                (int32_t) std::min((size_t) n_batch, tokens.size() - i);
            llama_batch batch = llama_batch_get_one(tokens.data() + i, n);
            if (llama_decode(h->ctx, batch) != 0) failed = true;
        }

        int32_t produced = 0;
        const int32_t limit = max_tokens > 0 ? max_tokens : 256;
        while (!failed && produced < limit && !h->cancel.load()) {
            llama_token tok = llama_sampler_sample(smpl, h->ctx, -1);
            if (llama_vocab_is_eog(h->vocab, tok)) break;

            char piece[256];
            int32_t n = llama_token_to_piece(h->vocab, tok, piece,
                                             sizeof(piece), 0, true);
            if (n > 0) {
                char * out = (char *) malloc(n + 1);
                memcpy(out, piece, n);
                out[n] = '\0';
                cb(out, user);
            }
            produced++;

            llama_batch batch = llama_batch_get_one(&tok, 1);
            if (llama_decode(h->ctx, batch) != 0) break;
        }

        llama_sampler_free(smpl);
        cb(nullptr, user); // done / cancelled / failed — always close the stream
        h->busy.store(false);
    });
    return 0;
}

void ppllm_cancel(void * handle) {
    auto * h = (PpLlm *) handle;
    if (h) h->cancel.store(true);
}

int32_t ppllm_busy(void * handle) {
    auto * h = (PpLlm *) handle;
    return (h && h->busy.load()) ? 1 : 0;
}

void ppllm_free(void * handle) {
    delete (PpLlm *) handle;
}

void ppllm_string_free(char * s) { free(s); }

const char * ppllm_last_error(void) { return g_last_error.c_str(); }

} // extern "C"
