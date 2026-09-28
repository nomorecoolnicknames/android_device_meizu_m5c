// libm5cshim_tinycompress — the twelve tinycompress calls audio.primary
// .mt6737m.so imports, all answering "no compressed offload".
//
// The HAL uses them only for AUDIO_OUTPUT_FLAG_COMPRESS_OFFLOAD streams, and
// this device's audio_policy_configuration.xml declares no offload output
// (the stock conf has none on the primary module), so AudioFlinger never
// opens one.  They exist because the loader needs every import resolved.
// The real library is not an option: external/tinycompress's vendor variant
// needs generated kernel headers, which a prebuilt-kernel tree cannot make
// (device.mk, libtinycompress note).  Nor can this library carry the name
// libtinycompress.so — that install path belongs to the Soong module of the
// same name — so the HAL's DT_NEEDED is rewritten to it at build time
// (vendor/meizu/m5c treble-elf-wiring.txt, REPLACE rule of blob-elf-wire.py).
//
// Behaviour mirrors tinycompress on failure: compress_open never returns
// NULL (a static "bad" handle, as its bad_compress), the calls fail with -1
// and errno ENODEV, and every entry point tolerates that handle or NULL.
#include <errno.h>

struct compress;
struct compr_config;
struct compr_gapless_mdata;

namespace {
char bad_compress;
}

extern "C" {

struct compress* compress_open(unsigned int, unsigned int, unsigned int, struct compr_config*) {
    errno = ENODEV;
    return reinterpret_cast<struct compress*>(&bad_compress);
}

void compress_close(struct compress*) {}

int is_compress_ready(struct compress*) { return 0; }

const char* compress_get_error(struct compress*) {
    return "compressed offload is not available on this build";
}

int compress_get_tstamp(struct compress*, unsigned long*, unsigned int*) {
    errno = ENODEV;
    return -1;
}

int compress_write(struct compress*, const void*, unsigned int) {
    errno = ENODEV;
    return -1;
}

int compress_start(struct compress*) {
    errno = ENODEV;
    return -1;
}

int compress_stop(struct compress*) {
    errno = ENODEV;
    return -1;
}

int compress_pause(struct compress*) {
    errno = ENODEV;
    return -1;
}

int compress_resume(struct compress*) {
    errno = ENODEV;
    return -1;
}

int compress_set_gapless_metadata(struct compress*, struct compr_gapless_mdata*) {
    errno = ENODEV;
    return -1;
}

void compress_nonblock(struct compress*, int) {}

}  // extern "C"
