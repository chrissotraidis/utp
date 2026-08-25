#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static uint64_t entry_offset(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) return 0;
    struct mach_header_64 header;
    if (fread(&header, sizeof(header), 1, file) != 1 || header.magic != MH_MAGIC_64) { fclose(file); return 0; }
    for (uint32_t i = 0; i < header.ncmds; ++i) {
        struct load_command command;
        long position = ftell(file);
        if (fread(&command, sizeof(command), 1, file) != 1) break;
        if (command.cmd == LC_MAIN) {
            struct entry_point_command main_command;
            fseek(file, position, SEEK_SET);
            if (fread(&main_command, sizeof(main_command), 1, file) == 1) { fclose(file); return main_command.entryoff; }
        }
        fseek(file, position + command.cmdsize, SEEK_SET);
    }
    fclose(file);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2 && argc != 3) return fprintf(stderr, "usage: %s ENGINE_DYLIB [--invoke]\n", argv[0]), 2;
    int flags = getenv("UT99_DLOPEN_LAZY") ? RTLD_LAZY : RTLD_NOW;
    void *handle = dlopen(argv[1], flags | RTLD_LOCAL);
    if (!handle) return fprintf(stderr, "dlopen failed: %s\n", dlerror()), 1;
    puts("hosted Mach-O load succeeded");
    if (argc == 3 && strcmp(argv[2], "--invoke") == 0) {
        uint64_t offset = entry_offset(argv[1]);
        intptr_t slide = 0;
        for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
            const char *name = _dyld_get_image_name(i);
            if (name && strcmp(name, argv[1]) == 0) { slide = _dyld_get_image_vmaddr_slide(i); break; }
        }
        if (!offset || !slide) return fprintf(stderr, "could not locate hosted LC_MAIN\n"), 3;
        char *args[] = {"UnrealTournament", "-log", "-nosound", NULL};
        int (*original_main)(int, char **) = (int (*)(int, char **))((uintptr_t)slide + 0x100000000ULL + offset);
        puts("invoking original LC_MAIN entry");
        return original_main(3, args);
    }
    dlclose(handle);
    return 0;
}
