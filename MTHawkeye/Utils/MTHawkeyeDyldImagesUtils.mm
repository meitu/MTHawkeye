//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/10/30
// Created by: EuanC
//


#import "MTHawkeyeDyldImagesUtils.h"

#import <dlfcn.h>
#import <mach-o/arch.h>
#import <mach-o/dyld.h>
#import <string.h>


#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif


#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
#endif

#if defined(__i386__)

#define MY_THREAD_STATE_COUTE x86_THREAD_STATE32_COUNT
#define MY_THREAD_STATE x86_THREAD_STATE32
#define MY_EXCEPTION_STATE_COUNT x86_EXCEPTION_STATE64_COUNT
#define MY_EXCEPITON_STATE ARM_EXCEPTION_STATE32
#define MY_SEGMENT_CMD_TYPE LC_SEGMENT

#elif defined(__x86_64__)

#define MY_THREAD_STATE_COUTE x86_THREAD_STATE64_COUNT
#define MY_THREAD_STATE x86_THREAD_STATE64
#define MY_EXCEPTION_STATE_COUNT x86_EXCEPTION_STATE64_COUNT
#define MY_EXCEPITON_STATE x86_EXCEPTION_STATE64
#define MY_SEGMENT_CMD_TYPE LC_SEGMENT_64

#elif defined(__arm64__)

#define MY_THREAD_STATE_COUTE ARM_THREAD_STATE64_COUNT
#define MY_THREAD_STATE ARM_THREAD_STATE64
#define MY_EXCEPTION_STATE_COUNT ARM_EXCEPTION_STATE64_COUNT
#define MY_EXCEPITON_STATE ARM_EXCEPTION_STATE64
#define MY_SEGMENT_CMD_TYPE LC_SEGMENT_64

#elif defined(__arm__)

#define MY_THREAD_STATE_COUTE ARM_THREAD_STATE_COUNT
#define MY_THREAD_STATE ARM_THREAD_STATE
#define MY_EXCEPITON_STATE ARM_EXCEPTION_STATE
#define MY_EXCEPTION_STATE_COUNT ARM_EXCEPTION_STATE_COUNT
#define MY_SEGMENT_CMD_TYPE LC_SEGMENT

#else
#error Unsupported host cpu.
#endif

static void process_binary_image(const void *header, struct uuid_command *out_uuid) {
    uint32_t ncmds;
    const struct mach_header *header32 = (const struct mach_header *)header;
    const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;

    struct load_command *cmd;

    /* Check for 32-bit/64-bit header and extract required values */
    switch (header32->magic) {
            /* 32-bit */
        case MH_MAGIC:
        case MH_CIGAM:
            ncmds = header32->ncmds;
            cmd = (struct load_command *)(header32 + 1);
            break;

            /* 64-bit */
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            ncmds = header64->ncmds;
            cmd = (struct load_command *)(header64 + 1);
            break;

        default:
            NSLog(@"Invalid Mach-O header magic value: %x", header32->magic);
            return;
    }

    /* Compute the image size and search for a UUID */
    struct uuid_command *uuid = NULL;

    for (uint32_t i = 0; cmd != NULL && i < ncmds; i++) {
        /* DWARF dSYM UUID */
        if (cmd->cmd == LC_UUID && cmd->cmdsize == sizeof(struct uuid_command))
            uuid = (struct uuid_command *)cmd;

        cmd = (struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
    }

    if (out_uuid && uuid)
        memcpy(out_uuid, uuid, sizeof(struct uuid_command));
}

// MARK: - public
void mtha_setup_dyld_images_dumper_with_path(NSString *filepath) {
    NSMutableArray *dyldImages = @[].mutableCopy;

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char *name = _dyld_get_image_name(i);
        const mach_header *header = (const mach_header *)_dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        int64_t imageBaseAddr = (uint64_t)header;

        struct uuid_command uuid = {0};
        char uuidstr[64] = {0};
        process_binary_image(header, &uuid);
        for (int i = 0; i < 16; i++)
            sprintf(&uuidstr[2 * i], "%02x", uuid.uuid[i]);

        NSString *uuidStr = [NSString stringWithCString:uuidstr encoding:NSASCIIStringEncoding];
        NSDictionary *image_info = @{
            @"uuid" : uuidStr ?: @"",
            @"base_addr" : [NSString stringWithFormat:@"0x%llx", imageBaseAddr],
            @"addr_slide" : [NSString stringWithFormat:@"0x%lx", slide],
            @"name" : [NSString stringWithUTF8String:name],
        };
        [dyldImages addObject:image_info];
    }

    NSString *version = nil;
    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = [NSString stringWithUTF8String:info->description];
    NSString *executableName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *model = nil;

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    version = [[UIDevice currentDevice] systemVersion];
    model = [[UIDevice currentDevice] valueForKey:@"buildVersion"];
#else

#endif

    NSDictionary *cacheInfo = @{
        @"os_version" : version ?: @"",
        @"arch" : typeOfCpu ?: @"",
        @"model" : model ?: @"",
        @"name" : executableName ?: @"",
        @"dyld_images" : dyldImages ?: @""
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:cacheInfo options:NSJSONWritingPrettyPrinted error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [str writeToFile:filepath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static vm_address_t images_begin = 0;
static vm_address_t images_end = 0;
static vm_address_t sys_images_begin = 0;

#ifndef DEBUG_DYLD_IMAGE_ORDER_ENABLE
#define DEBUG_DYLD_IMAGE_ORDER_ENABLE 0
#endif

static void read_dyld_images_range() {
    if (sys_images_begin == 0) {
        uint32_t count = _dyld_image_count();

#if DEBUG_DYLD_IMAGE_ORDER_ENABLE
        NSMutableArray *images = @[].mutableCopy;
#endif

        for (uint32_t i = 0; i < count; ++i) {
            const char *name = _dyld_get_image_name(i);

#if TARGET_IPHONE_SIMULATOR
            /*
             For simulator, the order of the dyld images is quick radom(for user frameworks)
             a index set is needed for this case, here we just care about the main execution.

             dyld image: 4384235520, /Users/euanc/Library/Dev ~~~/aaaa.app/aaaa   // <---
             dyld image: 4641890304, /Library/Developer/CoreS ~~~ /Frameworks/ImageIO.framework/ImageIO
             dyld image: 4648280064, /Users/euanc/Library/Dev ~~~ /aaaa.app/Frameworks/Manis.framework/Manis // <---
             dyld image: 4771450880, /Users/euanc/Library/Dev ~~~ /aaaa.app/Frameworks/libswiftARKit.dylib
             ...
             */
            bool is_sys_image = true;
            if (strncmp(name, "/Users/", 7) == 0 && (strstr(name, "libswift")) == NULL) {
                is_sys_image = false;
            }

#else // !TARGET_IPHONE_SIMULATOR
            /*
             dyld image: 4295786496, /var/containers/Bundle/Appl ~~~ /aaaa.app/aaaa  // <---
             dyld image: 4478582784, /Developer/Library/PrivateFrameworks/libViewDebuggerSupport.dylib
             dyld image: 4483235840, /private/var/containers/Bun ~~~ aaaa.app/Frameworks/Manis.framework/Manis  // <---
             dyld image: 4501782528, /private/var/containers/Bun ~~~ aaaa.app/Frameworks/libswiftMapKit.dylib
             dyld image: 6628442112, /usr/lib/libobjc.A.dylib
             ...
             */
            bool is_sys_image = true;
            if ((strncmp(name, "/var/", 5) == 0)) {
                is_sys_image = false;
            } else if ((strncmp(name, "/private/var/", 13) == 0)) {
                if (strstr(name, "libswift") == NULL)
                    is_sys_image = false;
            }
#endif

            const mach_header *header = (const mach_header *)_dyld_get_image_header(i);
            int64_t begin = (uint64_t)header;

            if ((sys_images_begin > begin || sys_images_begin == 0) && is_sys_image) {
                sys_images_begin = (vm_address_t)begin;
            } else if (!is_sys_image) {
#if DEBUG_DYLD_IMAGE_ORDER_ENABLE
                printf("dyld image 0: %lld, %s\n", begin, name);
#endif
            }
#if DEBUG_DYLD_IMAGE_ORDER_ENABLE
            [images addObject:@[ @(begin), @(name) ]];
#endif

            if (images_begin > begin || images_begin == 0) {
                images_begin = (vm_address_t)begin;
            }
            if (images_end < begin) {
                images_end = (vm_address_t)begin;
            }
        }

#if DEBUG_DYLD_IMAGE_ORDER_ENABLE
        [images sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
            return [obj1[0] integerValue] > [obj2[0] integerValue] ? NSOrderedAscending : NSOrderedDescending;
        }];
        [images enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            printf("dyld image: %ld, %s \n", (long)[obj[0] integerValue], [obj[1] UTF8String]);
        }];
#endif
    }
}

boolean_t mtha_addr_is_in_sys_libraries(vm_address_t address) {
    read_dyld_images_range();
    // need improve for user frameworks.
    if (address >= sys_images_begin) {
        return true;
    } else {
        return false;
    }
}

boolean_t mtha_symbol_addr_check_basic(vm_address_t address) {
    read_dyld_images_range();
    if (address > images_begin && address < images_end) {
        return true;
    } else {
        return false;
    }
}

// MARK: -
static NSArray *cacheDyldImagesRange = nil;
static NSArray *cachedDyldImages = nil;
static NSDictionary *curDyldImages = nil;

#ifdef DEBUG
static NSDictionary *curDyldImage = nil;
#endif

static boolean_t loadCachedDyldImages(NSString *cachedDyldImagesFilePath) {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:cachedDyldImagesFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"failed: %@", error);
        return false;
    }

    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dyldImagesInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSArray *images = dyldImagesInfo[@"dyld_images"];

    NSMutableArray *tmpImages = @[].mutableCopy;
    for (NSDictionary *image in images) {
        uint64_t baseAddr = (uint64_t)strtoull([image[@"base_addr"] UTF8String], NULL, 16);
        NSMutableDictionary *tmpImg = [image mutableCopy];
        tmpImg[@"base_addr"] = @(baseAddr);
        [tmpImages addObject:[tmpImg copy]];
    }
    [tmpImages sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj1[@"base_addr"] integerValue] > [obj2[@"base_addr"] integerValue] ? NSOrderedDescending : NSOrderedAscending;
    }];
    cachedDyldImages = [tmpImages copy];
    return true;
}

static void loadCurDyldImages() {
    uint32_t count = _dyld_image_count();
    NSMutableDictionary *images = @{}.mutableCopy;
    for (uint32_t i = 0; i < count; ++i) {
        // find the lowest system binary image beginAddr.
        const mach_header *header = (const mach_header *)_dyld_get_image_header(i);
        int64_t imageBaseAddr = (uint64_t)header;

        struct uuid_command uuid = {0};
        char uuidstr[64] = {0};
        process_binary_image(header, &uuid);
        for (int i = 0; i < 16; i++)
            sprintf(&uuidstr[2 * i], "%02x", uuid.uuid[i]);

        NSString *uuidStr = [NSString stringWithCString:uuidstr encoding:NSASCIIStringEncoding];

        NSDictionary *image = @{
            @"uuid" : uuidStr ?: @"",
            @"base_addr" : [NSString stringWithFormat:@"%llu", imageBaseAddr],
        };

#ifdef DEBUG
        if (i == 0) {
            curDyldImage = image;
        }
#endif

        images[uuidStr] = image;
    }

    curDyldImages = [images copy];
}

boolean_t mtha_start_dyld_restore(NSString *cachedDyldImages) {
    loadCachedDyldImages(cachedDyldImages);
    loadCurDyldImages();
    return true;
}

uint64_t mtha_dyld_restore_address(uint64_t org_address) {
    NSDictionary *cachedImage = @{@"base_addr" : @(org_address)};
    NSUInteger matchedImageIdx = -1;
    for (NSUInteger idx = 0; idx < cachedDyldImages.count - 1; ++idx) {
        uint64_t curAddr = [cachedDyldImages[idx][@"base_addr"] integerValue];
        uint64_t nextAddr = [cachedDyldImages[idx + 1][@"base_addr"] integerValue];
        if (curAddr < org_address && org_address < nextAddr) {
            matchedImageIdx = idx;
            break;
        }
    }
    if (matchedImageIdx == -1)
        return 0;

    cachedImage = cachedDyldImages[matchedImageIdx];
    NSString *uuid = cachedImage[@"uuid"];

    NSDictionary *curImage = curDyldImages[uuid];
    if (curImage == nil) {
        // recompile and run will make a new image uuid.
        // this will only happen when upgrade app or debugging.
        // when debug, we simply assume it keep the same.
#ifdef DEBUG
        return org_address;
#else
        // we can't restore
        return 0;
#endif
    }
    int64_t diff = [cachedImage[@"base_addr"] integerValue] - [curImage[@"base_addr"] integerValue];
    return org_address -= diff;
}

void mtha_end_dyld_restore() {
    cachedDyldImages = nil;
    curDyldImages = nil;
}
