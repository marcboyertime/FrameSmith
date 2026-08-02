// Narrow directory-exchange helper for the isolated copied-app transaction.
// It deliberately provides no fallback for platforms without macOS
// renameatx_np(..., RENAME_SWAP): a non-atomic replacement is unsafe here.

#define _DARWIN_C_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#if !defined(__APPLE__)
#error "fcpcc-atomic-swap requires macOS renameatx_np(RENAME_SWAP)"
#endif

#ifndef RENAME_SWAP
#define RENAME_SWAP 0x00000002
#endif

static void fail(const char *message) {
    fprintf(stderr, "fcpcc-atomic-swap: %s\n", message);
    exit(1);
}

static void requireCanonicalDirectory(const char *input, char resolved[PATH_MAX], struct stat *metadata) {
    if (realpath(input, resolved) == NULL) {
        fprintf(stderr, "fcpcc-atomic-swap: cannot canonicalize %s: %s\n", input, strerror(errno));
        exit(1);
    }
    if (strcmp(input, resolved) != 0) {
        fail("directory paths must already be canonical");
    }
    struct stat linkMetadata;
    if (lstat(input, &linkMetadata) != 0) {
        fprintf(stderr, "fcpcc-atomic-swap: cannot lstat %s: %s\n", input, strerror(errno));
        exit(1);
    }
    if (S_ISLNK(linkMetadata.st_mode)) {
        fail("symlink directory targets are forbidden");
    }
    if (stat(input, metadata) != 0) {
        fprintf(stderr, "fcpcc-atomic-swap: cannot stat %s: %s\n", input, strerror(errno));
        exit(1);
    }
    if (!S_ISDIR(metadata->st_mode)) {
        fail("each exchange target must be a directory");
    }
}

int main(int argc, const char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "usage: fcpcc-atomic-swap <canonical-directory-a> <canonical-directory-b>\n");
        return 64;
    }

    char first[PATH_MAX];
    char second[PATH_MAX];
    struct stat firstMetadata;
    struct stat secondMetadata;
    requireCanonicalDirectory(argv[1], first, &firstMetadata);
    requireCanonicalDirectory(argv[2], second, &secondMetadata);
    if (strcmp(first, second) == 0) {
        fail("exchange targets must be distinct");
    }
    if (firstMetadata.st_dev != secondMetadata.st_dev) {
        fail("exchange targets are not on the same volume");
    }
    size_t firstLength = strlen(first);
    size_t secondLength = strlen(second);
    if ((strncmp(first, second, firstLength) == 0 && second[firstLength] == '/') ||
        (strncmp(second, first, secondLength) == 0 && first[secondLength] == '/')) {
        fail("nested exchange targets are forbidden");
    }
    if (renameatx_np(AT_FDCWD, first, AT_FDCWD, second, RENAME_SWAP) != 0) {
        fprintf(stderr, "fcpcc-atomic-swap: renameatx_np(RENAME_SWAP) failed: %s\n", strerror(errno));
        return 1;
    }
    printf("atomic_swap=pass\n");
    return 0;
}
