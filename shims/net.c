/* libmtkshim_net: ifc_ipv6_trigger_rs for the MTK RIL blobs.
 *
 * mtk-ril.so and mtk-rilmd2.so import ifc_ipv6_trigger_rs, an MTK addition to
 * libnetutils. It sends an ICMPv6 Router Solicitation on the given interface
 * so SLAAC does not wait for the next unsolicited Router Advertisement. The
 * signature is inferred from the blob, not taken from an MTK header.
 *
 * rild holds CAP_NET_RAW, and the kernel fills in the ICMPv6 checksum for raw
 * IPPROTO_ICMPV6 sockets (RFC 3542 section 3.1).
 */
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/icmp6.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

int ifc_ipv6_trigger_rs(const char *ifname) {
    struct icmp6_hdr rs;
    struct sockaddr_in6 dst;
    int s, hops = 255, ret = -1;

    if (ifname == NULL)
        return -1;

    memset(&rs, 0, sizeof(rs));
    rs.icmp6_type = ND_ROUTER_SOLICIT;

    memset(&dst, 0, sizeof(dst));
    dst.sin6_family = AF_INET6;
    inet_pton(AF_INET6, "ff02::2", &dst.sin6_addr); /* all-routers */
    dst.sin6_scope_id = if_nametoindex(ifname);
    if (dst.sin6_scope_id == 0)
        return -1;

    s = socket(AF_INET6, SOCK_RAW | SOCK_CLOEXEC, IPPROTO_ICMPV6);
    if (s < 0)
        return -1;

    /* RFC 4861 section 4.1: an RS must be sent with hop limit 255, and the
     * receiver must discard it otherwise. */
    setsockopt(s, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, &hops, sizeof(hops));
    setsockopt(s, IPPROTO_IPV6, IPV6_UNICAST_HOPS, &hops, sizeof(hops));

    if (sendto(s, &rs, sizeof(rs), 0, (struct sockaddr *)&dst,
               sizeof(dst)) == (ssize_t)sizeof(rs))
        ret = 0;

    close(s);
    return ret;
}
