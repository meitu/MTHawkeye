//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/7/4
// Created by: EuanC
//


#import "MTHANRTracingBuffer.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeUtility.h"

#import <sys/mman.h>
#import <vector>


// MARK: - Activity
NSString *mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivity activity) {
    switch (activity) {
        case MTHawkeyeAppLifeActivityWillEnterForeground:
            return @"willEnterForeground";
        case MTHawkeyeAppLifeActivityDidEnterBackground:
            return @"didEnterBackground";
        case MTHawkeyeAppLifeActivityDidBecomeActive:
            return @"didBecomeActive";
        case MTHawkeyeAppLifeActivityWillResignActive:
            return @"willResignActive";
        case MTHawkeyeAppLifeActivityWillTerminate:
            return @"willTerminate";
        case MTHawkeyeAppLifeActivityMemoryWarning:
            return @"memoryWarning";
        case MTHawkeyeAppLifeActivityBackgroundTaskWillOutOfTime:
            return @"bgTaskRunOutOfTime";
        default:
            return [NSString stringWithFormat:@"%@", @(activity)];
    }
}

NSString *mthStringFromRunloopActivity(CFRunLoopActivity activity) {
    if (activity == kCFRunLoopEntry)
        return @"entry";
    else if (activity == kCFRunLoopBeforeTimers)
        return @"beforeTimers";
    else if (activity == kCFRunLoopBeforeSources)
        return @"beforeSources";
    else if (activity == kCFRunLoopBeforeWaiting)
        return @"beforeWaiting";
    else if (activity == kCFRunLoopAfterWaiting)
        return @"afterWaiting";
    else if (activity == kCFRunLoopExit)
        return @"exit";
    return [NSString stringWithFormat:@"%@", @(activity)];
}

// MARK: - MTHANRTracingBufferContext

BOOL mthMmapANRTracingBufferContextOn(NSString *filepath, NSString *openAttr, MTHANRTracingBufferContext **out_context, FILE **out_fp, size_t *out_filesize) {
    if (filepath.length == 0) return NO;

    FILE *fp = fopen([filepath UTF8String], [openAttr UTF8String]);
    if (fp == NULL) {
        MTHLogWarn(@"[ANR] failed to open %@", filepath);
        return NO;
    }

    size_t sz = sizeof(MTHANRTracingBufferContext);
    if (sz < getpagesize() || (sz % getpagesize() != 0)) {
        sz = (sz / getpagesize() + 1) * getpagesize(); // 16KB on 64bit device
        if (ftruncate(fileno(fp), sz) != 0) {
            MTHLogWarn("[ANR] fail to truncate:%s, size:%zu\n", strerror(errno), sz);
            return NO;
        }
    }
    MTHANRTracingBufferContext *ptr = (MTHANRTracingBufferContext *)mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (ptr == MAP_FAILED) {
        MTHLogWarn(@"[ANR] failed to mmap %@, size: %@", filepath, @(sz));
        return NO;
    }

    *out_fp = fp;
    *out_context = (MTHANRTracingBufferContext *)ptr;
    *out_filesize = sz;
    return YES;
}

BOOL mthUmmapANRTracingBufferContextOn(MTHANRTracingBufferContext *context, FILE *mmapFile, size_t size) {
    if (context) {
        msync(context, size, MS_ASYNC);
        munmap(context, size);
        context = NULL;
    }

    if (mmapFile) {
        fclose(mmapFile);
        mmapFile = NULL;
    }
    return YES;
}

NSString *mthPreviousSessionBufferPath(NSString *currentSessionPath) {
    return [currentSessionPath stringByAppendingString:@"_prev"];
}

BOOL mthBackupSessionTracingBufferAsPrevious(NSString *sessionFile) {
    NSError *error;
    NSString *prevPath = mthPreviousSessionBufferPath(sessionFile);
    if ([[NSFileManager defaultManager] fileExistsAtPath:prevPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:prevPath error:&error]) {
            MTHLogWarn(@"[ANR] remove previous backup failed, %@", error);
            return NO;
        }
    }
    if (![[NSFileManager defaultManager] copyItemAtPath:sessionFile toPath:prevPath error:&error]) {
        MTHLogWarn(@"[ANR] backup previous failed, %@", error);
        return NO;
    }
    return YES;
}

MTHANRTracingBufferContext mthANRTracingBufferContextFromMmapFile(NSString *filepath) {
    MTHANRTracingBufferContext outContext;

    MTHANRTracingBufferContext *context = NULL;
    FILE *file = NULL;
    size_t filesize = NULL;
    BOOL success = mthMmapANRTracingBufferContextOn(filepath, @"rb+", &context, &file, &filesize);
    if (success) {
        memcpy(&outContext, context, sizeof(MTHANRTracingBufferContext));
        mthUmmapANRTracingBufferContextOn(context, file, filesize);
    }
    return outContext;
}

// MARK: Activities write & read

void mthSaveRunloopActivityToContext(MTHANRTracingBufferContext *context, CFRunLoopActivity activity, NSTimeInterval time) {
    NSInteger insertIdx = context->runloopActivitiesStartIndex;
    MTHawkeyeRunloopActivityRecord record = {.activity = activity, .time = time};
    context->runloopActivities[insertIdx] = record;
    insertIdx = (insertIdx + 1) % kMTHawkeyeRunloopActivitiesBufferCount;
    context->runloopActivitiesStartIndex = insertIdx;
}

std::vector<MTHawkeyeRunloopActivityRecord> mthReadRunloopActivitiesFromContext(MTHANRTracingBufferContext *context) {
    std::vector<MTHawkeyeRunloopActivityRecord> records = std::vector<MTHawkeyeRunloopActivityRecord>();
    for (NSInteger count = 0; count < kMTHawkeyeRunloopActivitiesBufferCount; ++count) {
        NSInteger idx = (context->runloopActivitiesStartIndex + count) % kMTHawkeyeRunloopActivitiesBufferCount;
        MTHawkeyeRunloopActivityRecord record = context->runloopActivities[idx];
        if (record.time > 0)
            records.push_back(record);
    }
    return records;
}

void mthSaveAppLifeActivityToContext(MTHANRTracingBufferContext *context, MTHawkeyeAppLifeActivity activity, NSTimeInterval time) {
    NSInteger insertIdx = context->appLifeActivitiesStartIndex;
    MTHawkeyeAppLifeActivityRecord record = {.activity = activity, .time = time};
    context->appLifeActivities[insertIdx] = record;
    insertIdx = (insertIdx + 1) % kMTHawkeyeAppLifeActivitiesBufferCount;
    context->appLifeActivitiesStartIndex = insertIdx;
}

std::vector<MTHawkeyeAppLifeActivityRecord> mthReadAppLifeActivitiesFromContext(MTHANRTracingBufferContext *context) {
    std::vector<MTHawkeyeAppLifeActivityRecord> records = std::vector<MTHawkeyeAppLifeActivityRecord>();
    for (NSInteger count = 0; count < kMTHawkeyeAppLifeActivitiesBufferCount; ++count) {
        NSInteger idx = (context->stackFramesStartIndex + count) % kMTHawkeyeAppLifeActivitiesBufferCount;
        MTHawkeyeAppLifeActivityRecord record = context->appLifeActivities[idx];
        if (record.time > 0)
            records.push_back(record);
    }
    return records;
}

BOOL mthSaveStackBacktraceToContext(MTHANRTracingBufferContext *context, mth_stack_backtrace *backtrace, NSTimeInterval time) {
    if (backtrace == NULL || backtrace->frames_size == 0 || backtrace->frames == NULL) {
        return NO;
    }

    // for each stack frames, it need (stackframes_size + 2) space to store the info.
    // - the first position store the size,
    // - the last position store the time.
    // - the remain is the stack frames.

    size_t size = backtrace->frames_size;
    NSInteger startFrom = (context->stackFramesStartIndex) % kMTHawkeyeStackBacktracesBufferLimit;

    NSInteger replacingExistFrames = -1;
    for (NSInteger i = 0; i < size + 2; ++i) {
        NSInteger curIdx = (startFrom + i) % kMTHawkeyeStackBacktracesBufferLimit;
        NSInteger nextIdx = (curIdx + 1) % kMTHawkeyeStackBacktracesBufferLimit;

        // not enough buffer for frames, take place from the oldest stack frames.
        uintptr_t existValue = context->stackBacktraces[curIdx];
        if (existValue > 0 && replacingExistFrames == -1) {
            replacingExistFrames = existValue;
        }

        if (replacingExistFrames >= 0) {
            replacingExistFrames -= 1;

            context->stackBacktraces[nextIdx] = replacingExistFrames;

            if (replacingExistFrames == 0) {
                context->stackBacktraces[(nextIdx + 1) % kMTHawkeyeStackBacktracesBufferLimit] = 0; // erase the time info.
                replacingExistFrames = -1;                                                          // reset, may need to occupy second oldest stack frames
            }
        }

        if (i == 0) {
            context->stackBacktraces[curIdx] = size;
        } else if (i == size + 1) {
            context->stackBacktraces[curIdx] = time * 1e6;
        } else {
            context->stackBacktraces[curIdx] = backtrace->frames[size - i];
        }
    }
    context->stackFramesStartIndex = (startFrom + size + 2) % kMTHawkeyeStackBacktracesBufferLimit;
    return YES;
}

// MAKR:
NSDictionary *mthDictionaryFromANRTracingBufferContext(MTHANRTracingBufferContext *context) {
    std::vector<MTHawkeyeRunloopActivityRecord> runloopRecords = mthReadRunloopActivitiesFromContext(context);
    std::vector<MTHawkeyeAppLifeActivityRecord> applifeRecords = mthReadAppLifeActivitiesFromContext(context);

    NSMutableArray *runloopActivities = [NSMutableArray array];
    for (NSInteger count = 0; count < kMTHawkeyeRunloopActivitiesBufferCount; ++count) {
        NSInteger idx = (context->runloopActivitiesStartIndex + count) % kMTHawkeyeRunloopActivitiesBufferCount;
        MTHawkeyeRunloopActivityRecord record = context->runloopActivities[idx];
        if (record.time != 0) {
            [runloopActivities addObject:@{
                @"activity" : mthStringFromRunloopActivity(record.activity),
                @"time" : @(record.time)
            }];
        }
    }

    NSMutableArray *applifeActivities = [NSMutableArray array];
    for (NSInteger count = 0; count < kMTHawkeyeAppLifeActivitiesBufferCount; ++count) {
        NSInteger idx = (context->appLifeActivitiesStartIndex + count) % kMTHawkeyeAppLifeActivitiesBufferCount;
        MTHawkeyeAppLifeActivityRecord record = context->appLifeActivities[idx];
        if (record.time != 0) {
            [applifeActivities addObject:@{
                @"activity" : mthStringFromAppLifeActivity(record.activity),
                @"time" : @(record.time)
            }];
        }
    }

    NSMutableArray *stackbacktrace = [NSMutableArray array];
    for (NSInteger count = 0; count < kMTHawkeyeStackBacktracesBufferLimit; ++count) {

        // for each stack frames, it use (stackframes_size + 2) space to store the info.
        // - the first position store the size,
        // - the last position store the time.
        // - the remain is the stack frames.

        NSInteger startFrom = (context->stackFramesStartIndex + count) % kMTHawkeyeStackBacktracesBufferLimit;
        if (context->stackBacktraces[startFrom] == 0) {
            continue;
        }

        // the first position store the count of the frame.
        size_t framesSize = context->stackBacktraces[startFrom];

        NSMutableString *framesStr = [NSMutableString string];
        for (NSInteger idx = framesSize; idx > 0; --idx) {
            NSInteger i = (startFrom + idx) % kMTHawkeyeStackBacktracesBufferLimit;
            [framesStr appendFormat:@"%p,", (void *)context->stackBacktraces[i]];
        }

        // the last position store the time.
        NSTimeInterval time = context->stackBacktraces[(startFrom + framesSize + 1) % kMTHawkeyeStackBacktracesBufferLimit] / 1e6;
        if (framesStr.length > 0) {
            [stackbacktrace addObject:@{
                @"time" : @(time),
                @"frames" : [framesStr substringToIndex:framesStr.length - 1]
            }];
        }

        count += (framesSize + 1);
    }

    NSDictionary *result = @{
        @"runloop" : runloopActivities,
        @"applife" : applifeActivities,
        @"stackbacktrace" : stackbacktrace
    };
    return result;
}


// MARK: - MTHANRTracingBuffer

static BOOL _tracingBufferRunning = NO;
static MTHANRTracingBufferContext *_context = NULL;
static FILE *_file = NULL;
static size_t _fileSize = 0;
static NSString *_bufferFilePath = NULL;

@interface MTHANRTracingBuffer ()
@end

@implementation MTHANRTracingBuffer

+ (BOOL)enableTracingBufferOn:(NSString *)bufferFilePath {
    if (_tracingBufferRunning) {
        MTHLogWarn(@"ANR Traing Buffer already run, do nothing.");
        return NO;
    }

    _bufferFilePath = bufferFilePath;

    if (![[NSFileManager defaultManager] fileExistsAtPath:_bufferFilePath]) {
        NSMutableDictionary *fileAttr = [NSMutableDictionary dictionary];
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
        [fileAttr setObject:NSFileProtectionCompleteUntilFirstUserAuthentication
                     forKey:NSFileProtectionKey];
#endif
        if (![[NSFileManager defaultManager] createFileAtPath:_bufferFilePath contents:nil attributes:fileAttr]) {
            MTHLogWarn(@"[ANR] create directory %@ failed", _bufferFilePath);
            return NO;
        }
    } else {
        mthBackupSessionTracingBufferAsPrevious(_bufferFilePath);
    }

    BOOL success = mthMmapANRTracingBufferContextOn(_bufferFilePath, @"wb+", &_context, &_file, &_fileSize);
    if (success) {
        bzero(_context, _fileSize);
    }

    _tracingBufferRunning = YES;

    return YES;
}

+ (BOOL)isTracingBufferRunning {
    return _tracingBufferRunning;
}

+ (void)disableTracingBuffer {
    if (mthUmmapANRTracingBufferContextOn(_context, _file, _fileSize)) {
        _context = NULL;
        _file = NULL;
        _fileSize = 0;
    }

    _tracingBufferRunning = NO;
}

// MARK: Write

+ (BOOL)traceRunloopActivity:(CFRunLoopActivity)activity {
    if (!_tracingBufferRunning || !_context) return NO;

    mthSaveRunloopActivityToContext(_context, activity, [MTHawkeyeUtility currentTime]);
    return YES;
}

+ (BOOL)traceAppLifeActivity:(MTHawkeyeAppLifeActivity)activity {
    if (!_tracingBufferRunning || !_context) return NO;

    mthSaveAppLifeActivityToContext(_context, activity, [MTHawkeyeUtility currentTime]);
    return YES;
}

+ (BOOL)traceStackBacktrace:(mth_stack_backtrace *)backtrace {
    if (!_tracingBufferRunning || !_context) return NO;

    return mthSaveStackBacktraceToContext(_context, backtrace, [MTHawkeyeUtility currentTime]);
}

// MARK: Read

+ (void)readCurrentSessionBufferInDict:(void (^)(NSDictionary *_Nullable))completionHandler {
    if (!completionHandler) return;

    if (!_context) {
        completionHandler(nil);
    } else {
        NSDictionary *resultInDict = mthDictionaryFromANRTracingBufferContext(_context);
        completionHandler(resultInDict);
    }
}

+ (void)readPreviousSessionBufferInDict:(void (^)(NSDictionary *_Nullable))completionHandler {
    if (!completionHandler) return;

    if (_bufferFilePath.length == 0) {
        MTHLogWarn(@"bufferFilePath needed for load previous session buffer.");
        completionHandler(nil);
    } else {
        NSString *prevBufferPath = mthPreviousSessionBufferPath(_bufferFilePath);
        MTHANRTracingBufferContext context = mthANRTracingBufferContextFromMmapFile(prevBufferPath);
        NSDictionary *resultInDict = mthDictionaryFromANRTracingBufferContext(&context);
        completionHandler(resultInDict);
    }
}

@end
