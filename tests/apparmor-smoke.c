/* Run via aa-exec under the smoke profile. The unrestricted caller creates
 * both writable fixtures first, so EACCES must come from profile enforcement. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char label[256] = {0};
    int fd = open("/proc/self/attr/apparmor/current", O_RDONLY | O_CLOEXEC);
    if (fd < 0) { perror("read AppArmor label"); return 1; }
    ssize_t n = read(fd, label, sizeof(label) - 1);
    close(fd);
    if (n < 0) { perror("read label"); return 1; }
    if (!strstr(label, "microvm-smoke (enforce)")) {
        fprintf(stderr, "Unexpected AppArmor label: %s\n", label); return 1;
    }
    fd = open("/tmp/aa-allowed", O_WRONLY | O_TRUNC | O_CLOEXEC);
    if (fd < 0) { perror("allowed write"); return 1; }
    if (write(fd, "allowed\n", 8) != 8) { perror("write"); close(fd); return 1; }
    close(fd);
    errno = 0;
    fd = open("/tmp/aa-denied", O_WRONLY | O_TRUNC | O_CLOEXEC);
    if (fd >= 0) { close(fd); fprintf(stderr, "Denied write succeeded\n"); return 1; }
    if (errno != EACCES) { perror("expected EACCES"); return 1; }
    puts("AppArmor enforce profile: allowed write passed, denied write blocked");
    return 0;
}
