/* Isolated boot-test fixture: persistent TUN and real marked UDP packets. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

static void fail(const char *what) { perror(what); exit(1); }
static int tun_open(void) {
    int fd = open("/dev/net/tun", O_RDWR | O_CLOEXEC);
    if (fd < 0) fail("open TUN");
    struct ifreq req = {.ifr_flags = IFF_TUN | IFF_NO_PI};
    strcpy(req.ifr_name, "ts-smoke");
    if (ioctl(fd, TUNSETIFF, &req)) fail("TUNSETIFF");
    return fd;
}
static void packet(int family, int marked) {
    int fd = socket(family, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (fd < 0) fail("UDP socket");
    if (marked) {
        uint32_t mark = 0x80000;
        if (setsockopt(fd, SOL_SOCKET, SO_MARK, &mark, sizeof(mark))) fail("SO_MARK");
    }
    struct sockaddr_storage addr = {0};
    socklen_t size;
    if (family == AF_INET) {
        struct sockaddr_in *a = (void *)&addr;
        a->sin_family = family; a->sin_port = htons(38451);
        a->sin_addr.s_addr = htonl(marked ? 0xc6120001 : INADDR_LOOPBACK);
        size = sizeof(*a);
    } else {
        struct sockaddr_in6 *a = (void *)&addr;
        a->sin6_family = family; a->sin6_port = htons(38452);
        a->sin6_addr = in6addr_loopback;
        if (marked) { memset(&a->sin6_addr, 0, sizeof(a->sin6_addr)); a->sin6_addr.s6_addr[0] = 0xfd; a->sin6_addr.s6_addr[15] = 1; }
        size = sizeof(*a);
    }
    if (sendto(fd, "test", 4, 0, (void *)&addr, size) != 4) fail("send UDP");
    close(fd);
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (!strcmp(argv[1], "--create-tun")) {
        int fd = tun_open();
        if (ioctl(fd, TUNSETPERSIST, 1)) fail("TUNSETPERSIST");
        close(fd);
        puts("TUN created");
    } else if (!strcmp(argv[1], "--marked-routes")) {
        int tun = tun_open();
        for (int i = 0; i < 2; ++i) {
            int version = i ? 6 : 4;
            packet(i ? AF_INET6 : AF_INET, 1);
            struct pollfd wait = {.fd = tun, .events = POLLIN};
            int seen = 0;
            for (int n = 0; n < 8 && !seen; ++n) {
                if (poll(&wait, 1, 3000) <= 0) fail("TUN packet timeout");
                unsigned char buf[2048];
                ssize_t size = read(tun, buf, sizeof(buf));
                if (size < 1) fail("TUN read");
                /* Ignore IPv6 neighbour discovery or unrelated packets: the
                 * selected route must deliver our UDP payload/destination. */
                if (version == 4 && size >= 32 && (buf[0] >> 4) == 4 &&
                    buf[9] == IPPROTO_UDP && buf[16] == 198 && buf[17] == 18 &&
                    buf[18] == 0 && buf[19] == 1 && !memcmp(buf + size - 4, "test", 4))
                    seen = 1;
                if (version == 6 && size >= 52 && (buf[0] >> 4) == 6 &&
                    buf[6] == IPPROTO_UDP && buf[24] == 0xfd && buf[39] == 1 &&
                    !memcmp(buf + size - 4, "test", 4))
                    seen = 1;
            }
            if (!seen) { fprintf(stderr, "Missing IPv%d TUN packet\n", version); return 1; }
            printf("IPv%d fwmark route delivered a packet to TUN\n", version);
        }
        close(tun);
    } else if (!strcmp(argv[1], "--loopback")) {
        packet(AF_INET, 0); packet(AF_INET6, 0);
        puts("IPv4/IPv6 loopback packets sent for MARK/CONNMARK counters");
    } else return 2;
    return 0;
}
