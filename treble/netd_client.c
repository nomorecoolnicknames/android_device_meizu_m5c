





















#include <android/multinetwork.h>
#include <errno.h>
#include <stdint.h>

#define NETID_UNSET 0u /* system/netd/include/netid_client.h */

/* kHandleMagic of frameworks/base/native/android/net.c. */
static const uint32_t kHandleMagic = 0xcafed00d;

__attribute__((visibility("default"))) int setNetworkForSocket(unsigned netId, int socketFd) {
    net_handle_t handle = netId == NETID_UNSET
            ? NETWORK_UNSPECIFIED
            : ((net_handle_t)netId << 32) | kHandleMagic;

    if (android_setsocknetwork(handle, socketFd) == 0)
        return 0;
    return -errno;
}
