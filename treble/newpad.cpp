// libm5cshim_newpad — what the N-era camera closure must find before libc++
// and libutils: operator new with slack, and a Thread::run that tolerates a
// missing thread name.
//

// libmtk_mmutils and libmmsdkservice.feature allocate android::GraphicBuffer
// themselves with the Nougat size, _Znwj(136), and then call the constructor;
// libmmsdkservice.feature does the same for BufferItemConsumer, _Znwj(1064).
// The Android 13 objects the shim constructors (camera.cpp) build there are
// 160 and 1080 bytes (sizeof with the A13 headers, arm32), i.e. 24 and 16
// bytes past the block — heap corruption.
//
// This library is prepended to the DT_NEEDED of the camera dlopen roots —
// camera.mt6737m.so at module load, libcam_platform.so at camera open (FACT,
// set 17/18: the devicemgr dlopen()s it, and libcam.client / libcam.device1
// come in with it) — and of libMtkOmxVenc (vendor/meizu/m5c
// treble-elf-wiring.txt).  bionic resolves every library loaded by that
// dlopen against the global group and then the root's local group in
// breadth-first order, so these definitions come before libc++'s for the
// whole camera closure.  Every block gets kSlack spare bytes at its end; the
// pointer is malloc's own, so libc++'s operator delete (free) stays correct,
// sized or not.  Surface (N 1776 bytes, A13 several KiB) is out of reach and
// refused in camera.cpp instead.
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
// FACT (set 18, camera open): the provider aborted with "thread name not
// provided to Thread::run" — libcam.client's
// NSCamClient::NSPrvCbClient::PreviewClient::init() calls run() without a
// name, which Nougat's libutils accepted and Android 13's refuses
// (LOG_ALWAYS_FATAL in Threads.cpp).  This library is the first DT_NEEDED of
// the camera dlopen roots, so the closure binds run() here; a missing name
// becomes "m5c-N-thread" and the call goes on to libutils (RTLD_NEXT).
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
