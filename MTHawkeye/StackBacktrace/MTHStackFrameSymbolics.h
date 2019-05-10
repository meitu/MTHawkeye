//
//  MTHStackFrameSymbolics.h
//  MTHawkeye
//

#ifndef MTH_STACK_FRAME_SYMBOLICS_H
#define MTH_STACK_FRAME_SYMBOLICS_H

#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <execinfo.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/vm_types.h>
#import <malloc/malloc.h>

typedef struct _mthawkeye_dyld_image_ {
    const char *name;         // image name
    long loadAddr;            // header 地址
    long beginAddr;           // __text 代码段开始地址
    long endAddr;             // __text 结束地址
    uintptr_t imageVMAddr;    // image 基址
    uint64_t imageSubFileoff; // vmaddr - fileoff
    struct symtab_command symtab_cmd;
    uint64_t symtableAddr; // 符号段起始地址
    uint32_t imageIndex;   // image index
} mthawkeye_dyld_image;


class MTHStackFrameSymbolics
{
  public:
    MTHStackFrameSymbolics();
    ~MTHStackFrameSymbolics();

    bool getDLInfoByAddr(vm_address_t addr, Dl_info *const info, bool slide);

  private:
    uint32_t getImageInfoIndexByAddress(const uintptr_t address);

    mthawkeye_dyld_image *allImageInfo;
    uint32_t imageInfoCount;
};

#endif /* MTH_STACK_FRAME_SYMBOLICS_H */
