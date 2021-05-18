//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2020/11/13
// Created by: whw
//


#import "MTHawkeyeAverageStorage.h"
#import "MTHawkeyeUtility.h"
#import "MTHawkeyeLogMacros.h"
#import <sys/mman.h>

static const char *_fileChar = NULL;

static CGFloat _memTotal = 0.0;
static int _memCount = 0;
static double _cpuTotal = 0.0;
static int _cpuCount = 0;
static int _fpsTotal = 0;
static int _fpsCount = 0;
static int _glfpsTotal = 0;
static int _glfpsCount = 0;

@implementation MTHawkeyeAverageStorage

+ (void)setupIfNeeded {
    if (_fileChar) {
        return;
    }
    NSString *storagePath = [MTHawkeyeUtility currentStorePath];
    NSString *path = [storagePath stringByAppendingPathComponent:@"average"];
    if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
        MTHLogWarn(@"[Average] create directory %@ failed", path);
        return;
    }
    const char *filePath = path.UTF8String;
    if (!filePath) {
        return;
    }
    int fd = open(filePath, O_CREAT | O_RDWR, 0666);
    if (fd < 0) {
        MTHLogWarn(@"[Average] failed to open %@", path);
        return;
    }
    size_t sz = getpagesize();
    char *ptr = (char *)mmap(NULL, sz, PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        MTHLogWarn(@"[Average] failed to mmap %@, size: %@", path, @(sz));
        return;
    }
    ftruncate(fd, sz);
    _fileChar = ptr;
}

+ (void)record {
    [self setupIfNeeded];
    if (_fileChar) {
        const char *record = [NSString stringWithFormat:@"\357\273\277CPU: %.1f%%\nMemory: %.1fM\nFPS: %.1f\nglFPS: %.1f\n",
                              _cpuTotal / MAX(_cpuCount, 1),
                              _memTotal / MAX(_memCount, 1),
                              (CGFloat)_fpsTotal / MAX(_fpsCount, 1),
                              (CGFloat)_glfpsTotal / MAX(_glfpsCount, 1)
                              ].UTF8String;
        memcpy((void *)_fileChar, (void *)record, strlen(record));
    }
}

+ (void)recordMem:(CGFloat)memory {
    _memCount++;
    _memTotal += memory;
    [self record];
}

+ (void)recordCPU:(double)cpu {
    _cpuCount++;
    _cpuTotal += cpu * 100.f;
    [self record];
}

+ (void)recordFPS:(int)fps {
    _fpsCount++;
    _fpsTotal += fps;
    [self record];
}

+ (void)recordglFPS:(int)fps {
    _glfpsCount++;
    _glfpsTotal += fps;
    [self record];
}

@end
