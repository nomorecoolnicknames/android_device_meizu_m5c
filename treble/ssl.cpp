// libm5cshim_ssl — SSLv3_client_method / SSLv3_server_method for the N-era
// GPS blobs.  BoringSSL dropped SSLv3; Android 13's libssl exports only the
// version-flexible methods.
//

// by /vendor/bin/mnld (from proprietary/xbin/mnld), so without this mnld
// cannot link at all — and bin/mtk_agpsd.  Wired to them at build time
// (vendor/meizu/m5c treble-elf-wiring.txt).  Same answer as m95
// (device/meizu/m95/shims/ssl.c): the version-flexible TLS methods, which is
// what any SUPL server still reachable negotiates anyway.
#include <openssl/ssl.h>

extern "C" {

const SSL_METHOD* SSLv3_client_method(void) {
    return TLS_client_method();
}

const SSL_METHOD* SSLv3_server_method(void) {
    return TLS_server_method();
}

}  // extern "C"
