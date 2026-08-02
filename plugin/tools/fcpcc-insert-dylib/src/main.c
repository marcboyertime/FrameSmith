// Product-authored, header-padding-only LC_LOAD_DYLIB inserter.
//
// This source is intentionally not a copy of tyilo/insert_dylib. It retains a
// pinned upstream reference only for audit comparison. The implementation is
// narrow by design: two positional arguments, regular load command insertion,
// 64-bit Mach-O slices, and no payload shifting.

#include <errno.h>
#include <fcntl.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
    uint8_t *bytes;
    size_t size;
} mach_slice_t;

static void fail(const char *message) {
    (void)fprintf(stderr, "fcpcc-insert-dylib: %s\n", message);
    exit(1);
}

static uint32_t read_be32(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t read_be64(const uint8_t *bytes) {
    uint64_t high = read_be32(bytes);
    uint64_t low = read_be32(bytes + 4);
    return (high << 32) | low;
}

static void write_u32(void *address, uint32_t value) {
    (void)memcpy(address, &value, sizeof(value));
}

static size_t align8(size_t value) {
    if (value > SIZE_MAX - 7) {
        fail("load path is too long");
    }
    return (value + 7U) & ~(size_t)7U;
}

static int has_room(size_t base, size_t amount, size_t limit) {
    return base <= limit && amount <= limit - base;
}

static int is_dylib_command(uint32_t command) {
    return command == LC_LOAD_DYLIB || command == LC_LOAD_WEAK_DYLIB || command == LC_REEXPORT_DYLIB || command == LC_LOAD_UPWARD_DYLIB || command == LC_LAZY_LOAD_DYLIB;
}

static uint32_t first_section_offset(const struct segment_command_64 *segment, uint32_t command_size) {
    if (command_size < sizeof(*segment)) {
        fail("truncated segment command");
    }
    uint64_t section_bytes = (uint64_t)segment->nsects * sizeof(struct section_64);
    if (section_bytes > UINT32_MAX || command_size < sizeof(*segment) + (uint32_t)section_bytes) {
        fail("truncated section table");
    }

    const uint8_t *cursor = (const uint8_t *)segment + sizeof(*segment);
    uint32_t first = 0;
    for (uint32_t index = 0; index < segment->nsects; index += 1) {
        const struct section_64 *section = (const struct section_64 *)(const void *)(cursor + index * sizeof(struct section_64));
        if (section->offset != 0 && (first == 0 || section->offset < first)) {
            first = section->offset;
        }
    }
    return first;
}

static void insert_into_slice(mach_slice_t slice, const char *load_path) {
    if (slice.size < sizeof(struct mach_header_64)) {
        fail("Mach-O slice is too small");
    }

    struct mach_header_64 *header = (struct mach_header_64 *)(void *)slice.bytes;
    if (header->magic != MH_MAGIC_64) {
        fail("only native-endian 64-bit Mach-O slices are accepted");
    }
    if (!has_room(sizeof(*header), header->sizeofcmds, slice.size)) {
        fail("load-command region is outside the Mach-O slice");
    }

    uint8_t *command_cursor = slice.bytes + sizeof(*header);
    uint8_t *command_end = command_cursor + header->sizeofcmds;
    uint32_t first_payload_offset = 0;
    for (uint32_t index = 0; index < header->ncmds; index += 1) {
        if (!has_room((size_t)(command_cursor - slice.bytes), sizeof(struct load_command), slice.size)) {
            fail("truncated load command");
        }
        struct load_command *command = (struct load_command *)(void *)command_cursor;
        if (command->cmdsize < sizeof(struct load_command) || command_cursor + command->cmdsize > command_end) {
            fail("invalid load command size");
        }

        if (is_dylib_command(command->cmd)) {
            if (command->cmdsize < sizeof(struct dylib_command)) {
                fail("truncated dylib command");
            }
            const struct dylib_command *dylib = (const struct dylib_command *)(const void *)command_cursor;
            uint32_t name_offset = dylib->dylib.name.offset;
            if (name_offset < sizeof(struct dylib_command) || name_offset >= command->cmdsize) {
                fail("invalid dylib name offset");
            }
            const char *existing = (const char *)(const void *)(command_cursor + name_offset);
            size_t remaining = command->cmdsize - name_offset;
            if (memchr(existing, '\0', remaining) == NULL) {
                fail("unterminated dylib name");
            }
            if (strcmp(existing, load_path) == 0) {
                fail("requested load command already exists");
            }
        }

        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)(const void *)command_cursor;
            uint32_t candidate = first_section_offset(segment, command->cmdsize);
            if (candidate != 0 && (first_payload_offset == 0 || candidate < first_payload_offset)) {
                first_payload_offset = candidate;
            }
        }
        command_cursor += command->cmdsize;
    }

    if (command_cursor != command_end) {
        fail("load-command count does not match load-command size");
    }
    if (first_payload_offset == 0) {
        fail("no section payload boundary was found");
    }

    size_t path_bytes = strlen(load_path) + 1U;
    size_t new_command_size = align8(sizeof(struct dylib_command) + path_bytes);
    if (header->ncmds == UINT32_MAX || header->sizeofcmds > UINT32_MAX - new_command_size) {
        fail("load-command count or size would overflow");
    }
    size_t new_command_end = sizeof(*header) + header->sizeofcmds + new_command_size;
    if (new_command_end > first_payload_offset || new_command_end > slice.size) {
        fail("insufficient zero-filled header padding");
    }
    for (uint8_t *byte = command_end; byte < slice.bytes + new_command_end; byte += 1) {
        if (*byte != 0) {
            fail("header padding is not zero-filled");
        }
    }

    struct dylib_command *new_command = (struct dylib_command *)(void *)command_end;
    (void)memset(new_command, 0, new_command_size);
    new_command->cmd = LC_LOAD_DYLIB;
    new_command->cmdsize = (uint32_t)new_command_size;
    new_command->dylib.name.offset = sizeof(struct dylib_command);
    (void)memcpy((uint8_t *)new_command + sizeof(struct dylib_command), load_path, path_bytes);
    write_u32(&header->ncmds, header->ncmds + 1U);
    write_u32(&header->sizeofcmds, header->sizeofcmds + (uint32_t)new_command_size);
}

static void insert_into_file(uint8_t *bytes, size_t size, const char *load_path, unsigned int *slice_count) {
    if (size < sizeof(uint32_t)) {
        fail("file is too small");
    }

    uint32_t fat_magic = read_be32(bytes);
    if (fat_magic == FAT_MAGIC || fat_magic == FAT_MAGIC_64) {
        if (size < sizeof(struct fat_header)) {
            fail("truncated universal header");
        }
        uint32_t count = read_be32(bytes + sizeof(uint32_t));
        size_t arch_size = fat_magic == FAT_MAGIC_64 ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
        size_t table_offset = sizeof(struct fat_header);
        if (count == 0 || count > 16 || !has_room(table_offset, (size_t)count * arch_size, size)) {
            fail("invalid universal architecture table");
        }
        for (uint32_t index = 0; index < count; index += 1) {
            const uint8_t *arch = bytes + table_offset + index * arch_size;
            uint64_t offset = fat_magic == FAT_MAGIC_64 ? read_be64(arch + 8) : read_be32(arch + 8);
            uint64_t slice_size = fat_magic == FAT_MAGIC_64 ? read_be64(arch + 16) : read_be32(arch + 12);
            if (offset > size || slice_size > size - offset) {
                fail("universal architecture slice is outside file bounds");
            }
            mach_slice_t slice = { .bytes = bytes + (size_t)offset, .size = (size_t)slice_size };
            insert_into_slice(slice, load_path);
            *slice_count += 1U;
        }
        return;
    }

    mach_slice_t slice = { .bytes = bytes, .size = size };
    insert_into_slice(slice, load_path);
    *slice_count = 1U;
}

int main(int argc, char * const argv[]) {
    if (argc != 3) {
        (void)fprintf(stderr, "usage: fcpcc-insert-dylib <mach-o-path> <load-path>\n");
        return 64;
    }
    if (argv[2][0] == '\0') {
        fail("load path must not be empty");
    }

    int descriptor = open(argv[1], O_RDWR | O_CLOEXEC);
    if (descriptor < 0) {
        (void)fprintf(stderr, "fcpcc-insert-dylib: open failed: %s\n", strerror(errno));
        return 1;
    }
    struct stat file_status;
    if (fstat(descriptor, &file_status) != 0 || file_status.st_size <= 0) {
        (void)fprintf(stderr, "fcpcc-insert-dylib: invalid input file: %s\n", strerror(errno));
        (void)close(descriptor);
        return 1;
    }
    if ((uintmax_t)file_status.st_size > SIZE_MAX) {
        fail("input file is too large");
    }

    size_t size = (size_t)file_status.st_size;
    uint8_t *bytes = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, descriptor, 0);
    if (bytes == MAP_FAILED) {
        (void)fprintf(stderr, "fcpcc-insert-dylib: map failed: %s\n", strerror(errno));
        (void)close(descriptor);
        return 1;
    }

    unsigned int slice_count = 0;
    insert_into_file(bytes, size, argv[2], &slice_count);
    if (msync(bytes, size, MS_SYNC) != 0) {
        (void)fprintf(stderr, "fcpcc-insert-dylib: sync failed: %s\n", strerror(errno));
        (void)munmap(bytes, size);
        (void)close(descriptor);
        return 1;
    }
    (void)munmap(bytes, size);
    (void)close(descriptor);
    (void)printf("injected_load_command=%s slices=%u\n", argv[2], slice_count);
    return 0;
}
