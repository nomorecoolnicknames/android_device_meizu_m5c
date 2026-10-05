// libm5cshim_legacy — functions the M/N-era MediaTek blobs of m5c import from
// platform libraries that Android 13 no longer exports, in ANY namespace.
// Not a Treble problem as such (the loads fail without Treble too), but the
// Treble wiring is where the blobs get their DT_NEEDED on this library:
// vendor/meizu/m5c treble-elf-wiring.txt, applied at build time.

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

// android_memset16 — removed from libcutils in R; imported by
// gralloc.mt6737m (both ABIs; FACT, readelf).  Same as
// device/meizu/m95/shims/utils.cpp: count is in BYTES, a multiple of 2.
// (android_memset32 has no importer on m5c and is not provided.)
M5C_EXPORT void android_memset16(uint16_t* dst, uint16_t value, size_t count) {
    count /= sizeof(uint16_t);
    while (count-- > 0) *dst++ = value;
}

// __pthread_gettid — bionic-private in the M/N era, gone once
// pthread_gettid_np became public; imported (version LIBC) by the 32-bit
// lib/libvcodecdrv.so, lib/libMtkOmxVdecEx.so and lib/libmtkjpeg.so.

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

//   mtk-ril.so:   ifc_ccmni_md_cfg, ifc_set_txq_state (MTK additions to the
//                 N-era libnetutils);
//   librilmtk.so: strdup8to16, strndup16to8, strnlen16to8, strncpy16to8
//                 (libcutils <cutils/jstring.h>, gone in A13).
// The ccmni/txq calls only tune the data path, success is safe (as m95,
// device/meizu/m95/shims/net.c:76-90); the jstring set follows AOSP, below.
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

// libcutils' jstring helpers (cutils/jstring.h): librilmtk.so and
// librilmtkmd2.so (both ABIs) import strnlen16to8, strncpy16to8, strndup16to8
// and strdup8to16 (FACT, readelf --dyn-syms), A13 libcutils no longer exports
// them.  The bodies are those of AOSP (system/core/libcutils/strdup16to8.cpp
// and strdup8to16.cpp, Apache-2.0, as in los16-a9-platform) so callers get the
// real contract: UTF-8/modified-UTF-8 conversion, strnlen16to8 counting all n
// units, strncpy16to8 always NUL-terminating.  The earlier ASCII-only version
// stopped at the first NUL and did not terminate, which the documented pattern
// malloc(strnlen16to8(s,n)+1); strncpy16to8(buf,s,n) turns into an over-read

M5C_EXPORT size_t strnlen16to8(const char16_t* utf16Str, size_t len) {
    size_t utf8Len = 0;
    while (len != 0) {
        len--;
        unsigned int uic = *utf16Str++;
        size_t utf8Cur = utf8Len;
        if (uic > 0x07ff)
            utf8Len += 3;
        else if (uic > 0x7f || uic == 0)
            utf8Len += 2;
        else
            utf8Len++;
        if (utf8Len < utf8Cur) return SIZE_MAX - 1;  // overflow
    }
    if (utf8Len == SIZE_MAX) utf8Len = SIZE_MAX - 1;
    return utf8Len;
}

M5C_EXPORT char* strncpy16to8(char* utf8Str, const char16_t* utf16Str, size_t len) {
    char* utf8cur = utf8Str;
    while (len != 0) {
        len--;
        unsigned int uic = *utf16Str++;
        if (uic > 0x07ff) {
            *utf8cur++ = static_cast<char>((uic >> 12) | 0xe0);
            *utf8cur++ = static_cast<char>(((uic >> 6) & 0x3f) | 0x80);
            *utf8cur++ = static_cast<char>((uic & 0x3f) | 0x80);
        } else if (uic > 0x7f || uic == 0) {
            *utf8cur++ = static_cast<char>((uic >> 6) | 0xc0);
            *utf8cur++ = static_cast<char>((uic & 0x3f) | 0x80);
        } else {
            *utf8cur++ = static_cast<char>(uic);
            if (uic == 0) break;
        }
    }
    *utf8cur = '\0';
    return utf8Str;
}

M5C_EXPORT char* strndup16to8(const char16_t* s, size_t n) {
    if (s == nullptr) return nullptr;
    size_t len = strnlen16to8(s, n);
    if (len >= SIZE_MAX - 1) return nullptr;
    char* ret = static_cast<char*>(malloc(len + 1));
    if (ret == nullptr) return nullptr;
    strncpy16to8(ret, s, n);
    return ret;
}

#define M5C_UTF16_REPLACEMENT_CHAR 0xfffd
#define M5C_UTF8_SEQ_LENGTH(ch) (((0xe5000000 >> (((ch) >> 3) & 0x1e)) & 3) + 1)
#define M5C_UNICODE_UPPER_LIMIT 0x10fffd

static size_t strlen8to16(const char* utf8Str) {
    size_t len = 0;
    int ic;
    int expected = 0;
    while ((ic = *utf8Str++) != '\0') {
        if ((ic & 0xc0) == 0x80) {
            expected--;
            if (expected < 0) len++;
        } else {
            len++;
            expected = M5C_UTF8_SEQ_LENGTH(ic) - 1;
            if (expected == 3) len++;  // surrogate pair
        }
    }
    return len;
}

static uint32_t getUtf32FromUtf8(const char** pUtf8Ptr) {
    static const unsigned char leaderMask[4] = {0xff, 0x1f, 0x0f, 0x07};
    if (((**pUtf8Ptr) & 0xc0) == 0x80) {
        (*pUtf8Ptr)++;
        return M5C_UTF16_REPLACEMENT_CHAR;
    }
    int seq_len = M5C_UTF8_SEQ_LENGTH(**pUtf8Ptr);
    uint32_t ret = (**pUtf8Ptr) & leaderMask[seq_len - 1];
    if (**pUtf8Ptr == '\0') return ret;
    (*pUtf8Ptr)++;
    for (int i = 1; i < seq_len; i++, (*pUtf8Ptr)++) {
        if ((**pUtf8Ptr) == '\0') return M5C_UTF16_REPLACEMENT_CHAR;
        if (((**pUtf8Ptr) & 0xc0) != 0x80) return M5C_UTF16_REPLACEMENT_CHAR;
        ret = (ret << 6) | (0x3f & (**pUtf8Ptr));
    }
    return ret;
}

// AOSP returns an unterminated UTF-16 string of *out_len units; one extra unit
// is allocated and set to 0 here, which callers that follow the contract never
// read.
M5C_EXPORT char16_t* strdup8to16(const char* s, size_t* out_len) {
    if (s == nullptr) return nullptr;
    size_t len = strlen8to16(s);
    if (len >= SIZE_MAX / sizeof(char16_t)) return nullptr;
    char16_t* ret = static_cast<char16_t*>(malloc(sizeof(char16_t) * (len + 1)));
    if (ret == nullptr) return nullptr;
    char16_t* dest = ret;
    while (*s != '\0') {
        uint32_t c = getUtf32FromUtf8(&s);
        if (c <= 0xffff) {
            *dest++ = static_cast<char16_t>(c);
        } else if (c <= M5C_UNICODE_UPPER_LIMIT) {
            *dest++ = static_cast<char16_t>(0xd800 | ((c - 0x10000) >> 10));
            *dest++ = static_cast<char16_t>(0xdc00 | ((c - 0x10000) & 0x3ff));
        } else {
            *dest++ = M5C_UTF16_REPLACEMENT_CHAR;
        }
    }
    *dest = 0;
    if (out_len != nullptr) *out_len = dest - ret;
    return ret;
}

}  // extern "C"

// android::PermissionCache::checkCallingPermission — libpqservice (in the
// Mali closure) and libgui_ext import it; the VNDK variant of libbinder that
// vendor and sphal processes get has no PermissionCache at all.  Declared by
// hand so the mangled name matches the N-era ABI without a libbinder link.
// TEMPORARY answer, as on m95 (device/meizu/m95/shims/utils.cpp): grant.
// Risk: every permission check in those libraries passes, so only SELinux
// (pq.te: who may find and call the PQ service) limits their callers.
// Removal condition: a real check (getCallingUid() against the permission's
// holders) once a caller that must be refused is identified.
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
