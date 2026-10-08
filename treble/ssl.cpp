// SSLv3_client_method / SSLv3_server_method for the N-era GPS blobs
// (libcurl used by mnld, mtk_agpsd). BoringSSL dropped SSLv3, so return the
// version-flexible TLS methods.
#include <openssl/ssl.h>

extern "C" {

const SSL_METHOD* SSLv3_client_method(void) {
    return TLS_client_method();
}

const SSL_METHOD* SSLv3_server_method(void) {
    return TLS_server_method();
}

}  // extern "C"
