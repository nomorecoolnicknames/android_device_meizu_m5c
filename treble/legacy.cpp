// libm5cshim_legacy — functions the M/N-era MediaTek blobs of m5c import from
// platform libraries that Android 13 no longer exports, in ANY namespace.
// Not a Treble problem as such (the loads fail without Treble too), but the
// Treble wiring is where the blobs get their DT_NEEDED on this library:
// vendor/meizu/m5c treble-elf-wiring.txt, applied at build time.
// Evidence: meizu-fleet/designs/TREBLE_M5C_20260924.md §5.
#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include <android/log.h>

#define M5C_EXPORT __attribute__((visibility("default")))

extern "C" {

// __xlog_buf_printf — MediaTek "xlog" from the M-era MTK liblog; 138 vendor
// ELFs of this image import it, libdpframework/libpqservice/libpq_prot/libbwc
// in the Mali closure among them.
// ABI (FACT, lib64/libbwc.so, BWCService::readyToRun: w0 = 0, x1 = a
// .data.rel.ro record whose relocations point to "BWCService" at +0 and
// "BWCService ready" at +8, with 3 = ANDROID_LOG_DEBUG at +16):
//   int __xlog_buf_printf(int bufid, const struct xlog_record *rec, ...);
// bufid is a log_id_t, prio an android_LogPriority.
struct xlog_record {
    const char* tag_str;
    const char* fmt_str;
    int prio;
};

M5C_EXPORT int __xlog_buf_printf(int bufid, const struct xlog_record* rec, ...) {
    if (rec == nullptr || rec->fmt_str == nullptr) return -EINVAL;
    char msg[1024];
    va_list ap;
    va_start(ap, rec);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(msg, sizeof(msg), rec->fmt_str, ap);
#pragma clang diagnostic pop
    va_end(ap);
    if (bufid < LOG_ID_MAIN || bufid >= LOG_ID_MAX) bufid = LOG_ID_MAIN;
    return __android_log_buf_write(bufid, rec->prio, rec->tag_str, msg);
}

// android_memset16/android_memset32 — removed from libcutils in R; imported
// by gralloc.mt6737m (both ABIs). Same as device/meizu/m95/shims/utils.cpp:
// count is in BYTES, a multiple of the element size.
M5C_EXPORT void android_memset16(uint16_t* dst, uint16_t value, size_t count) {
    count /= sizeof(uint16_t);
    while (count-- > 0) *dst++ = value;
}

M5C_EXPORT void android_memset32(uint32_t* dst, uint32_t value, size_t count) {
    count /= sizeof(uint32_t);
    while (count-- > 0) *dst++ = value;
}

// __pthread_gettid — bionic-private in the M/N era, gone once
// pthread_gettid_np became public; imported (version LIBC) by the 32-bit
// lib/libvcodecdrv.so, lib/libMtkOmxVdecEx.so and lib/libmtkjpeg.so.
// libvcodecdrv sits in the 32-bit Mali closure: FACT (A13 boot 4, 2026-09-28)
// sphal refuses /vendor/lib/egl/libGLES_mali.so with "cannot locate symbol
// "__pthread_gettid" referenced by /vendor/lib/libvcodecdrv.so", every 32-bit
// process aborts in eglGetDisplay ("couldn't find an OpenGL ES
// implementation"), zygote32 among them, and its onrestart takes
// system_server down in a loop.  The LIBC version requirement is satisfied by
// an unversioned definition: this library has no verdef "LIBC", so
// find_verdef_version_index() returns kVersymGlobal (bionic linker.cpp:2715-2737)
// and the symbol's versym is VER_NDX_GLOBAL (linker_soinfo.cpp:108-115).
M5C_EXPORT pid_t __pthread_gettid(pthread_t thread) {
    return pthread_gettid_np(thread);
}

// RIL stack (the MTK Oreo libril of device/meizu/m5c/ril links this library,
// and rild's load graph is RTLD_GLOBAL, so the stock blobs resolve here).
// FACT (symbol audit of the mtk-ril.so closure against the A13 images,
// 2026-09-28): 30 libraries, exactly six symbols missing —
//   mtk-ril.so:   ifc_ccmni_md_cfg, ifc_set_txq_state (MTK additions to the
//                 N-era libnetutils);
//   librilmtk.so: strdup8to16, strndup16to8, strnlen16to8, strncpy16to8
//                 (libcutils <cutils/jstring.h>, gone in A13).
// Same shims as m95 (device/meizu/m95/shims/net.c:76-90, utils.cpp:3-45):
// the ccmni/txq calls only tune the data path, success is safe.
M5C_EXPORT int ifc_set_txq_state(const char* ifname, int state) {
    (void)ifname;
    (void)state;
    return 0;
}

M5C_EXPORT int ifc_ccmni_md_cfg(const char* ifname, int md_id, int ccmni_idx, int op) {
    (void)ifname;
    (void)md_id;
    (void)ccmni_idx;
    (void)op;
    return 0;
}

M5C_EXPORT size_t strnlen16to8(const char16_t* s, size_t n) {
    size_t r = 0;
    while (n-- > 0 && *s++) r++;
    return r;
}

M5C_EXPORT char* strncpy16to8(char* dest, const char16_t* src, size_t n) {
    char* d = dest;
    while (n-- > 0) {
        char16_t c = *src++;
        *d++ = (c < 0x80) ? static_cast<char>(c) : '?';
    }
    return dest;
}

M5C_EXPORT char* strndup16to8(const char16_t* s, size_t n) {
    n = strnlen16to8(s, n);
    char* r = static_cast<char*>(malloc(n + 1));
    if (r == nullptr) return nullptr;
    strncpy16to8(r, s, n);
    r[n] = '\0';
    return r;
}

M5C_EXPORT char16_t* strdup8to16(const char* s, size_t* out_len) {
    size_t n = strlen(s);
    char16_t* r = static_cast<char16_t*>(malloc((n + 1) * sizeof(char16_t)));
    if (r == nullptr) return nullptr;
    for (size_t i = 0; i < n; i++) r[i] = static_cast<char16_t>(static_cast<unsigned char>(s[i]));
    r[n] = 0;
    if (out_len != nullptr) *out_len = n;
    return r;
}

}  // extern "C"

// android::PermissionCache::checkCallingPermission — libpqservice (in the
// Mali closure) and libgui_ext import it; the VNDK variant of libbinder that
// vendor and sphal processes get has no PermissionCache at all. Bring-up
// answer, as on m95 (device/meizu/m95/shims/utils.cpp): grant. Declared by
// hand so the mangled name matches the N-era ABI without a libbinder link.
namespace android {
class String16;
class PermissionCache {
  public:
    M5C_EXPORT static bool checkCallingPermission(const String16& permission);
};
bool PermissionCache::checkCallingPermission(const String16&) {
    return true;
}
}  // namespace android
