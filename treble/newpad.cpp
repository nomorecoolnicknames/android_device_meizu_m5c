// operator new with slack and a Thread::run that tolerates a missing thread
// name, for the Nougat-era camera blobs.
//
// The blobs allocate GraphicBuffer (136 bytes) and BufferItemConsumer
// (1064 bytes) with the Nougat sizes; the Android 13 objects are 24 and 16
// bytes larger. This library is the first dependency of the camera dlopen
// roots, so its operator new is used for the whole camera closure and adds
// kSlack bytes to every block.
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

namespace {
constexpr size_t kSlack = 64;

void* padded(size_t size) {
    void* p = malloc(size + kSlack);
    if (p == nullptr) abort();  // what libc++'s operator new does without exceptions
    return p;
}

void* paddedNoThrow(size_t size) {
    return malloc(size + kSlack);
}
}  // namespace

#ifdef __LP64__
#define M5C_NEW "_Znwm"
#define M5C_NEW_ARRAY "_Znam"
#define M5C_NEW_NT "_ZnwmRKSt9nothrow_t"
#define M5C_NEW_ARRAY_NT "_ZnamRKSt9nothrow_t"
#else
#define M5C_NEW "_Znwj"
#define M5C_NEW_ARRAY "_Znaj"
#define M5C_NEW_NT "_ZnwjRKSt9nothrow_t"
#define M5C_NEW_ARRAY_NT "_ZnajRKSt9nothrow_t"
#endif

extern "C" {
__attribute__((visibility("default"))) void* m5c_new(size_t) __asm__(M5C_NEW);
__attribute__((visibility("default"))) void* m5c_new_array(size_t) __asm__(M5C_NEW_ARRAY);
__attribute__((visibility("default"))) void* m5c_new_nt(size_t, const void*) __asm__(M5C_NEW_NT);
__attribute__((visibility("default"))) void* m5c_new_array_nt(size_t, const void*)
        __asm__(M5C_NEW_ARRAY_NT);

void* m5c_new(size_t size) {
    return padded(size);
}
void* m5c_new_array(size_t size) {
    return padded(size);
}
void* m5c_new_nt(size_t size, const void*) {
    return paddedNoThrow(size);
}
void* m5c_new_array_nt(size_t size, const void*) {
    return paddedNoThrow(size);
}
}  // extern "C"

// ---- android::Thread::run(const char* name, int32_t priority, size_t stack) --
// The camera blobs call run() without a name, which Android 13 libutils
// refuses. Supply a default name and forward to libutils.
#ifdef __LP64__
#define M5C_THREAD_RUN "_ZN7android6Thread3runEPKcim"
#else
#define M5C_THREAD_RUN "_ZN7android6Thread3runEPKcij"
#endif

extern "C" {
__attribute__((visibility("default"))) int m5c_thread_run(void*, const char*, int32_t, size_t)
        __asm__(M5C_THREAD_RUN);

using M5cThreadRunFn = int (*)(void*, const char*, int32_t, size_t);
static M5cThreadRunFn gNextThreadRun;  // no C++ runtime here (stl: none): no guarded statics

int m5c_thread_run(void* self, const char* name, int32_t priority, size_t stack) {
    M5cThreadRunFn next = __atomic_load_n(&gNextThreadRun, __ATOMIC_ACQUIRE);
    if (next == nullptr) {
        next = reinterpret_cast<M5cThreadRunFn>(dlsym(RTLD_NEXT, M5C_THREAD_RUN));
        if (next == nullptr) abort();
        __atomic_store_n(&gNextThreadRun, next, __ATOMIC_RELEASE);
    }
    return next(self, name != nullptr ? name : "m5c-N-thread", priority, stack);
}
}  // extern "C"
