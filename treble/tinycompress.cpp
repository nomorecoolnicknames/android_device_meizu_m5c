// The twelve tinycompress calls audio.primary.mt6737m imports, all answering
// "no compressed offload". No offload output is declared in the audio policy.
// compress_open never returns NULL (a static bad handle, as in tinycompress),
// the calls fail with -1 and errno ENODEV.
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
