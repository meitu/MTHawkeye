//
//  MTHStackFrameSymbolics.mm
//  MTHawkeye
//

#import "MTHStackFrameSymbolics.h"

#include <mach-o/dyld.h>
#include <mach-o/nlist.h>


#if __has_feature(objc_arc)
//#error This file must be compiled without ARC. Use -fno-objc-arc flag.
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

#if defined(__LP64__)
#define MTHA_TRACE_FMT "%-4d%-31s 0x%016lx %s + %lu"
#define MTHA_POINTER_FMT "0x%016lx"
#define MTHA_POINTER_SHORT_FMT "0x%lx"
#define MTHA_NLIST struct nlist_64
#else
#define MTHA_TRACE_FMT "%-4d%-31s 0x%08lx %s + %lu"
#define MTHA_POINTER_FMT "0x%08lx"
#define MTHA_POINTER_SHORT_FMT "0x%lx"
#define MTHA_NLIST struct nlist
#endif


static inline int qcompare(const void *a, const void *b) {
    if ((*(mthawkeye_dyld_image *)a).beginAddr > (*(mthawkeye_dyld_image *)b).beginAddr) {
        return 1;
    } else {
        return -1;
    }
}

MTHStackFrameSymbolics::~MTHStackFrameSymbolics() {
    if (allImageInfo) {
        free(allImageInfo);
        allImageInfo = NULL;
    }
    imageInfoCount = 0;
}

static void load_dyld_images(mthawkeye_dyld_image *&allImageInfo, uint32_t &imageInfoCount) {
    uint32_t count = _dyld_image_count();
    allImageInfo = (mthawkeye_dyld_image *)malloc(count * sizeof(mthawkeye_dyld_image));
    imageInfoCount = 0;

    for (uint32_t i = 0; i < count; i++) {
        const mach_header_t *header = (const mach_header_t *)_dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        const char *tmp = strrchr(name, '/');
        if (tmp) {
            name = tmp + 1;
        }

        uintptr_t offset = (uintptr_t)header + sizeof(mach_header_t);
        uintptr_t slide = _dyld_get_image_vmaddr_slide(i); // image 基址
        uintptr_t begin = 0;
        uintptr_t end = 0;
        uint64_t subFileoff = 0;
        uint64_t symtableAddr = 0;
        bool isFindText = false;
        bool isFindLink = false;
        bool isFindSym = false;

        for (unsigned int i = 0; i < header->ncmds; i++) {
            const load_command *loadCmd = (const load_command *)offset;
            if (loadCmd->cmd == LC_SEGMENT) {
                const struct segment_command *segment = (const struct segment_command *)offset;
                // 记录 text 段
                if (!isFindText && strcmp(segment->segname, SEG_TEXT) == 0) {
                    isFindText = true;
                    begin = (uintptr_t)segment->vmaddr + slide;
                    end = (uintptr_t)(begin + segment->vmsize);
                }
                // 记录 linkedit 段
                if (!isFindLink && strcmp(segment->segname, SEG_LINKEDIT) == 0) {
                    isFindLink = true;
                    subFileoff = (uint64_t)(segment->vmaddr - segment->fileoff);
                }
            } else if (loadCmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment64 = (const struct segment_command_64 *)offset;
                if (!isFindText && strcmp(segment64->segname, SEG_TEXT) == 0) {
                    isFindText = true;
                    begin = (uintptr_t)segment64->vmaddr + slide;
                    end = (uintptr_t)(begin + segment64->vmsize);
                }
                if (!isFindLink && strcmp(segment64->segname, SEG_LINKEDIT) == 0) {
                    isFindLink = true;
                    subFileoff = (uint64_t)(segment64->vmaddr - segment64->fileoff);
                }
            }

            // 记录 symbol table
            if (!isFindSym && loadCmd->cmd == LC_SYMTAB) {
                isFindSym = true;
                symtableAddr = (uint64_t)loadCmd;
            }
            if (isFindLink && isFindText && isFindSym) {
                break;
            }
            offset += loadCmd->cmdsize;
        }
        allImageInfo[i].imageIndex = i;
        allImageInfo[i].loadAddr = (uintptr_t)header;
        allImageInfo[i].name = name;
        allImageInfo[i].beginAddr = begin;
        allImageInfo[i].endAddr = end;
        allImageInfo[i].imageVMAddr = slide;
        allImageInfo[i].imageSubFileoff = subFileoff;
        allImageInfo[i].symtableAddr = symtableAddr;

        imageInfoCount++;
    }

    qsort(allImageInfo, count, sizeof(mthawkeye_dyld_image), qcompare);
}

MTHStackFrameSymbolics::MTHStackFrameSymbolics() {
    load_dyld_images(allImageInfo, imageInfoCount);
}

// 查找 address 在哪个 image 内（二分 log n）
uint32_t MTHStackFrameSymbolics::getImageInfoIndexByAddress(const uintptr_t address) {
    if (imageInfoCount == 0) {
        return UINT_MAX;
    }

    uint32_t start = 0;
    uint32_t end = imageInfoCount - 1; // bug: 多线程下 imageInfoLen = 0  uint32 的 0 - 1 = 0xFFFFFFFF
    uint32_t mid = 0;
    while (start <= end) {
        mid = (start + end) >> 1;
        if (mid >= imageInfoCount) { // fix bug: mid 超范围
            return UINT_MAX;
        }
        if (address < allImageInfo[mid].beginAddr) {
            end = mid - 1;
        } else if (address >= allImageInfo[mid].endAddr) {
            start = mid + 1;
        } else {
            return mid;
        }
    }
    return UINT_MAX;
}

bool MTHStackFrameSymbolics::getDLInfoByAddr(vm_address_t addr, Dl_info *const info, bool slide) {
    const uint32_t index = getImageInfoIndexByAddress(addr);
    if (index == UINT_MAX) {
        info->dli_saddr = (void *)addr;
        return false;
    }

    const uintptr_t imageVMAddrSlide = allImageInfo[index].imageVMAddr;

    const MTHA_NLIST *bestMatch = NULL;
    uint64_t stringTable = 0;
    if (slide) {
        const uintptr_t addressWithSlide = addr - imageVMAddrSlide; // ASLR 随机地址偏移
        const uint64_t segmentBase = allImageInfo[index].imageSubFileoff + imageVMAddrSlide;

        uintptr_t bestDistance = ULONG_MAX;
        const struct symtab_command *symtabCmd = (struct symtab_command *)allImageInfo[index].symtableAddr;
        const MTHA_NLIST *symbolTable = (MTHA_NLIST *)(segmentBase + symtabCmd->symoff);
        stringTable = segmentBase + symtabCmd->stroff;

        // optimize: iSym 循环能去到百万次，待优化
        // 搜索离 addressWithSlide 最近的符号地址
        for (uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
            // n_value == 0 表示这个符号是 extern 的，外部的符号
            if (symbolTable[iSym].n_value != 0) {
                uintptr_t symbolBase = symbolTable[iSym].n_value;
                uintptr_t currentDistance = addressWithSlide - symbolBase;
                if ((addressWithSlide >= symbolBase) && (currentDistance <= bestDistance)) {
                    bestMatch = symbolTable + iSym;
                    bestDistance = currentDistance;
                }
            }
        }
    }

    if (bestMatch != NULL || !slide) {
        const mach_header_t *header = (mach_header_t *)allImageInfo[index].loadAddr;
        info->dli_fname = allImageInfo[index].name;
        info->dli_fbase = (void *)header;
        info->dli_sname = nullptr;

        if (bestMatch != NULL) {
            info->dli_saddr = (void *)(bestMatch->n_value + imageVMAddrSlide);
            info->dli_sname = (char *)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);

            if (*(info->dli_sname) == '_') {
                info->dli_sname++;
            } else if (*(info->dli_sname) == '<') {
                // 简单处理 <redacted> 符号，外部获取到时，使用 dli_addr 展示。
                info->dli_sname = NULL;
            }

            // n_type == 3 所有符号被删去
            if (info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                info->dli_sname = nullptr;
            }
        } else {
            info->dli_saddr = (void *)addr;
        }
    }

    return true;
}
