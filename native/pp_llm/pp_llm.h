// Prepper Pad's embedded LLM engine — a minimal C surface over llama.cpp so
// Dart FFI can run local AI IN-PROCESS. This is what makes the assistant work
// on iOS, where spawning a llama-server child process is forbidden; the same
// engine runs on macOS/Android/desktop so every platform shares one path.
//
// Threading contract: ppllm_generate() returns immediately and streams tokens
// from an internal thread via the callback. Each `piece` is malloc'd and MUST
// be freed by the receiver with ppllm_string_free (the Dart side reads then
// frees). A NULL piece signals end-of-generation (or cancellation/error).
#ifndef PP_LLM_H
#define PP_LLM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define PPLLM_API __declspec(dllexport)
#else
#define PPLLM_API __attribute__((visibility("default")))
#endif

typedef void (*ppllm_token_cb)(const char * piece /* malloc'd, NULL = done */,
                               void * user);

// Loads a GGUF model. n_gpu_layers: 99 = full Metal/GPU offload, 0 = CPU.
// Returns an opaque handle, or NULL (see ppllm_last_error).
PPLLM_API void * ppllm_load(const char * model_path,
                            int32_t n_ctx,
                            int32_t n_gpu_layers);

// Renders a chat into the model's own prompt template. roles/contents are
// parallel arrays of UTF-8 strings. Returns a malloc'd prompt string (free
// with ppllm_string_free), or NULL on error.
PPLLM_API char * ppllm_apply_template(void * handle,
                                      const char ** roles,
                                      const char ** contents,
                                      int32_t n_msgs);

// Starts generation on an internal thread; tokens arrive via cb (see the
// threading contract above). Returns 0 if the generation was started, -1 if
// the handle is busy or invalid. temp <= 0 selects greedy sampling.
PPLLM_API int32_t ppllm_generate(void * handle,
                                 const char * prompt,
                                 int32_t max_tokens,
                                 float temp,
                                 ppllm_token_cb cb,
                                 void * user);

// Asks the running generation (if any) to stop; the callback will still
// receive its final NULL.
PPLLM_API void ppllm_cancel(void * handle);

// True while a generation thread is running.
PPLLM_API int32_t ppllm_busy(void * handle);

PPLLM_API void ppllm_free(void * handle);

PPLLM_API void ppllm_string_free(char * s);

// Last error message from ppllm_load/apply_template (thread-local-ish; only
// meaningful right after a failure).
PPLLM_API const char * ppllm_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // PP_LLM_H
