# ppllm — Prepper Pad's embedded LLM engine (llama.cpp statically linked into
# one dynamic library that Dart FFI loads). Build via scripts/build_llm_*.sh,
# which pass -DLLAMA_DIR pointing at a llama.cpp checkout.
cmake_minimum_required(VERSION 3.21)
project(ppllm CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT DEFINED LLAMA_DIR)
  message(FATAL_ERROR "Pass -DLLAMA_DIR=/path/to/llama.cpp")
endif()

# llama.cpp as static pieces we absorb into our single dylib. Metal shaders
# are embedded into the binary (no .metallib file to lose at runtime).
set(BUILD_SHARED_LIBS OFF)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
if(APPLE)
  set(GGML_METAL ON CACHE BOOL "" FORCE)
  set(GGML_METAL_EMBED_LIBRARY ON CACHE BOOL "" FORCE)
endif()
add_subdirectory(${LLAMA_DIR} llama_build EXCLUDE_FROM_ALL)

add_library(ppllm SHARED pp_llm.cpp)
target_include_directories(ppllm PRIVATE ${LLAMA_DIR}/include ${LLAMA_DIR}/ggml/include)
target_link_libraries(ppllm PRIVATE llama)
set_target_properties(ppllm PROPERTIES
  OUTPUT_NAME "ppllm"
  MACOSX_RPATH ON
)
