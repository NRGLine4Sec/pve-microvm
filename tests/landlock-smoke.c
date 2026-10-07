/* Booted-guest test: run as an unprivileged user with an owned TMPDIR.
 * cc -O2 -Wall -Wextra -Werror tests/landlock-smoke.c -o landlock-smoke
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/landlock.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef LANDLOCK_ACCESS_FS_TRUNCATE
#define LANDLOCK_ACCESS_FS_TRUNCATE (1ULL << 14)
#endif

static void fail(const char *what) { perror(what); exit(1); }
static void path_join(char *dst, size_t size, const char *dir, const char *leaf) {
    int n = snprintf(dst, size, "%s/%s", dir, leaf);
    if (n < 0 || (size_t)n >= size) { errno = ENAMETOOLONG; fail("fixture path"); }
}
static void write_file(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (fd < 0) fail("allowed write");
    if (write(fd, "fixture\n", 8) != 8) fail("write");
    if (close(fd)) fail("close");
}
static void denied_write(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_CLOEXEC, 0600);
    if (fd >= 0) { close(fd); fprintf(stderr, "FAIL: outside write allowed\n"); exit(1); }
    if (errno != EACCES) fail("outside write: expected EACCES");
}
static void inherited_checks(const char *allowed, const char *outside) {
    write_file(allowed);
    denied_write(outside);
    errno = 0;
    if (truncate(outside, 0) == 0) { fprintf(stderr, "FAIL: outside truncate allowed\n"); exit(1); }
    if (errno != EACCES) fail("outside truncate: expected EACCES");
}
static void restrict_child(const char *base, const char *self) {
    char allowdir[4096], allowed[4096], outside[4096], newfile[4096], renamed[4096];
    path_join(allowdir, sizeof(allowdir), base, "allowed");
    path_join(allowed, sizeof(allowed), allowdir, "file");
    path_join(outside, sizeof(outside), base, "outside");
    path_join(newfile, sizeof(newfile), base, "denied-new");
    path_join(renamed, sizeof(renamed), allowdir, "renamed");
    struct landlock_ruleset_attr rules = {.handled_access_fs =
        LANDLOCK_ACCESS_FS_WRITE_FILE | LANDLOCK_ACCESS_FS_MAKE_REG |
        LANDLOCK_ACCESS_FS_REMOVE_FILE | LANDLOCK_ACCESS_FS_REFER |
        LANDLOCK_ACCESS_FS_TRUNCATE};
    int ruleset = syscall(SYS_landlock_create_ruleset, &rules, sizeof(rules), 0);
    if (ruleset < 0) fail("create ruleset");
    int dir = open(allowdir, O_PATH | O_CLOEXEC);
    if (dir < 0) fail("open allowed directory");
    struct landlock_path_beneath_attr rule = {.allowed_access = rules.handled_access_fs,
                                             .parent_fd = dir};
    if (syscall(SYS_landlock_add_rule, ruleset, LANDLOCK_RULE_PATH_BENEATH, &rule, 0))
        fail("add path rule");
    close(dir);
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)) fail("no_new_privs");
    if (syscall(SYS_landlock_restrict_self, ruleset, 0)) fail("restrict self");
    close(ruleset);
    inherited_checks(allowed, outside);
    denied_write(newfile);
    if (truncate(allowed, 0)) fail("allowed truncate");
    if (rename(allowed, renamed)) fail("allowed rename");
    errno = 0;
    if (rename(renamed, newfile) == 0) { fprintf(stderr, "FAIL: outside rename allowed\n"); exit(1); }
    if (errno != EACCES && errno != EXDEV) fail("outside rename: expected EACCES/EXDEV");
    if (rename(renamed, allowed)) fail("restore allowed rename");
    pid_t child = fork();
    if (child < 0) fail("fork");
    if (!child) { execl(self, self, "--child", allowed, outside, (char *)NULL); fail("exec"); }
    int status;
    if (waitpid(child, &status, 0) != child) fail("waitpid");
    if (!WIFEXITED(status) || WEXITSTATUS(status)) exit(1);
    puts("PASS: allowed write/truncate/rename; denied outside write/create/truncate/rename; fork+exec inheritance");
}
int main(int argc, char **argv) {
    if (getuid() == 0 || geteuid() == 0) { fprintf(stderr, "Run this smoke test unprivileged\n"); return 1; }
    if (argc == 4 && !strcmp(argv[1], "--child")) {
        inherited_checks(argv[2], argv[3]); puts("PASS: restrictions survived fork+exec"); return 0;
    }
    int abi = syscall(SYS_landlock_create_ruleset, NULL, 0, LANDLOCK_CREATE_RULESET_VERSION);
    if (abi < 0) fail("Landlock ABI query");
    printf("Landlock ABI %d (uid %lu)\n", abi, (unsigned long)getuid());
    if (abi < 3) { fprintf(stderr, "Landlock ABI >= 3 required\n"); return 1; }
    const char *tmp = getenv("TMPDIR");
    if (!tmp || tmp[0] != '/') { fprintf(stderr, "Set TMPDIR to an owned absolute test directory\n"); return 1; }
    char base[4096], allowdir[4096], allowed[4096], outside[4096], self[4096];
    path_join(base, sizeof(base), tmp, "landlock.XXXXXX");
    if (!mkdtemp(base)) fail("mkdtemp");
    path_join(allowdir, sizeof(allowdir), base, "allowed");
    path_join(allowed, sizeof(allowed), allowdir, "file");
    path_join(outside, sizeof(outside), base, "outside");
    if (mkdir(allowdir, 0700)) fail("mkdir");
    /* Establish DAC permits these operations before installing Landlock. */
    write_file(allowed); write_file(outside);
    ssize_t n = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (n < 0 || (size_t)n >= sizeof(self) - 1) fail("self path");
    self[n] = 0;
    fflush(NULL);
    pid_t child = fork();
    if (child < 0) fail("fork");
    if (!child) { restrict_child(base, self); return 0; }
    int status;
    if (waitpid(child, &status, 0) != child) fail("waitpid");
    /* Unsandboxed parent removes only its owned fixture after child exit. */
    unlink(allowed); unlink(outside); rmdir(allowdir); rmdir(base);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
