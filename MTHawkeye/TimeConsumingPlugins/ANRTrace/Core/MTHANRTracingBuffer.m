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

BOOL mthANRTracingBufferContextFromMmapFile(NSString *filepath, MTHANRTracingBufferContext *outContext) {
    if (outContext == nil) return NO;

    MTHANRTracingBufferContext *context = NULL;
    FILE *file = NULL;
    size_t filesize = 0;
    BOOL success = mthMmapANRTracingBufferContextOn(filepath, @"rb+", &context, &file, &filesize);
    if (success) {
        memcpy(outContext, context, sizeof(MTHANRTracingBufferContext));
        mthUmmapANRTracingBufferContextOn(context, file, filesize);
        return YES;
    }
    return NO;
}

// MARK: Activities write & read

void mthSaveRunloopActivityToContext(MTHANRTracingBufferContext *context, CFRunLoopActivity activity, NSTimeInterval time) {
    NSInteger insertIdx = context->runloopActivitiesStartIndex;
    MTHawkeyeRunloopActivityRecord record = {.activity = activity, .time = time};
    context->runloopActivities[insertIdx] = record;
    insertIdx = (insertIdx + 1) % kMTHawkeyeRunloopActivitiesBufferCount;
    context->runloopActivitiesStartIndex = insertIdx;
}

void mthReadRunloopActivitiesFromContext(MTHANRTracingBufferContext *context, void (^activityRecordReadHandler)(CFRunLoopActivity activity, NSTimeInterval time)) {
    if (!activityRecordReadHandler) return;

    for (NSInteger count = 0; count < kMTHawkeyeRunloopActivitiesBufferCount; ++count) {
        NSInteger idx = (context->runloopActivitiesStartIndex + count) % kMTHawkeyeRunloopActivitiesBufferCount;
        MTHawkeyeRunloopActivityRecord record = context->runloopActivities[idx];
        if (record.time > 0) {
            activityRecordReadHandler(record.activity, record.time);
        }
    }
}

void mthSaveAppLifeActivityToContext(MTHANRTracingBufferContext *context, MTHawkeyeAppLifeActivity activity, NSTimeInterval time) {
    NSInteger insertIdx = context->appLifeActivitiesStartIndex;
    MTHawkeyeAppLifeActivityRecord record = {.activity = activity, .time = time};
    context->appLifeActivities[insertIdx] = record;
    insertIdx = (insertIdx + 1) % kMTHawkeyeAppLifeActivitiesBufferCount;
    context->appLifeActivitiesStartIndex = insertIdx;
}

void mthReadAppLifeActivitiesFromContext(MTHANRTracingBufferContext *context, void (^activityRecordReadHandler)(MTHawkeyeAppLifeActivity activity, NSTimeInterval time)) {
    if (!activityRecordReadHandler) return;

    for (NSInteger count = 0; count < kMTHawkeyeAppLifeActivitiesBufferCount; ++count) {
        NSInteger idx = (context->appLifeActivitiesStartIndex + count) % kMTHawkeyeAppLifeActivitiesBufferCount;
        MTHawkeyeAppLifeActivityRecord record = context->appLifeActivities[idx];
        if (record.time > 0) {
            activityRecordReadHandler(record.activity, record.time);
        }
    }
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

void mthReadBacktraceRecordsFromContext(MTHANRTracingBufferContext *context, void (^backtraceRecordReadHandler)(NSArray<NSNumber *> *backtrace, NSTimeInterval time)) {
    if (!backtraceRecordReadHandler) return;

    for (NSInteger count = 0; count < kMTHawkeyeStackBacktracesBufferLimit; ++count) {
        // for each stack frames, it use (stackframes_size + 2) space to store the info.
        // - the first position store the size,
        // - the last position store the time.
        // - the remain is the stack frames.

        NSInteger startFrom = (context->stackFramesStartIndex + count) % kMTHawkeyeStackBacktracesBufferLimit;
        if (context->stackBacktraces[startFrom] == 0 || context->stackBacktraces[startFrom] >= kMTHawkeyeStackBacktracesBufferLimit) {
            continue;
        }

        NSMutableArray<NSNumber *> *frames = [NSMutableArray array];

        // the first position store the count of the frame.
        size_t framesSize = context->stackBacktraces[startFrom];
        for (NSInteger idx = framesSize; idx > 0; --idx) {
            NSInteger i = (startFrom + idx) % kMTHawkeyeStackBacktracesBufferLimit;
            [frames addObject:@(context->stackBacktraces[i])];
        }

        // the last position store the time.
        NSTimeInterval time = context->stackBacktraces[(startFrom + framesSize + 1) % kMTHawkeyeStackBacktracesBufferLimit] / 1e6;

        if (frames.count > 0 && time != 0) {
            backtraceRecordReadHandler([frames copy], time);
        }

        count += (framesSize + 1);
    }
}

// MARK: - MTHANRTracingBuffer

@interface MTHANRTracingBuffer ()

@property (nonatomic, assign) BOOL isAppStillActiveTheLastMoment;
@property (nonatomic, assign) BOOL isDuringHardStall;
@property (nonatomic, assign) NSTimeInterval hardStallDurationInSeconds;
@property (nonatomic, assign) BOOL isLastAppActivityBackgroundTaskWillRunOutOfTime;

@end

@implementation MTHANRTracingBuffer

- (instancetype)initWithRawContext:(MTHANRTracingBufferContext *)context {
    if (self = [super init]) {
        [self loadingBufferFromRawContext:context];
    }
    return self;
}

- (void)loadingBufferFromRawContext:(MTHANRTracingBufferContext *)context {
    // runloop activities
    NSMutableArray *runloopActivities = [NSMutableArray array];
    NSMutableArray *runloopActivitiesTimes = [NSMutableArray array];

    void (^runloopActivityReadHandler)(CFRunLoopActivity, NSTimeInterval) = ^(CFRunLoopActivity activity, NSTimeInterval time) {
        [runloopActivities addObject:@(activity)];
        [runloopActivitiesTimes addObject:@(time)];
    };
    mthReadRunloopActivitiesFromContext(context, runloopActivityReadHandler);

    // applife activities
    NSMutableArray *applifeActivities = [NSMutableArray array];
    NSMutableArray *applifeActivitiesTimes = [NSMutableArray array];
    void (^applifeActivityReadHandler)(MTHawkeyeAppLifeActivity, NSTimeInterval) = ^(MTHawkeyeAppLifeActivity activity, NSTimeInterval time) {
        [applifeActivities addObject:@(activity)];
        [applifeActivitiesTimes addObject:@(time)];
    };
    mthReadAppLifeActivitiesFromContext(context, applifeActivityReadHandler);

    // backtrace records.
    NSMutableArray *backtraceRecords = [NSMutableArray array];
    NSMutableArray *backtraceRecordTimes = [NSMutableArray array];
    void (^backtraceRecordReadHandler)(NSArray<NSNumber *> *, NSTimeInterval) = ^(NSArray<NSNumber *> *backtrace, NSTimeInterval time) {
        [backtraceRecords addObject:backtrace];
        [backtraceRecordTimes addObject:@(time)];
    };
    mthReadBacktraceRecordsFromContext(context, backtraceRecordReadHandler);

    self.runloopActivities = [runloopActivities copy];
    self.runloopActivitiesTimes = [runloopActivitiesTimes copy];
    self.applifeActivities = [applifeActivities copy];
    self.applifeActivitiesTimes = [applifeActivitiesTimes copy];
    self.backtraceRecords = [backtraceRecords copy];
    self.backtraceRecordTimes = [backtraceRecordTimes copy];

    [self checkIfNormallyExistOrStalling];
}

- (void)checkIfNormallyExistOrStalling {
    self.isDuringHardStall = NO;
    BOOL isSessionActiveTheLastMoment = YES;
    for (NSNumber *applifeActivityNum in [self.applifeActivities.reverseObjectEnumerator allObjects]) {
        NSInteger activity = [applifeActivityNum integerValue];
        if (activity == MTHawkeyeAppLifeActivityMemoryWarning) {
            continue;
        }

        if (activity == MTHawkeyeAppLifeActivityBackgroundTaskWillOutOfTime) {
            self.isLastAppActivityBackgroundTaskWillRunOutOfTime = YES;
        } else if (activity == MTHawkeyeAppLifeActivityWillTerminate || activity == MTHawkeyeAppLifeActivityDidEnterBackground) {
            isSessionActiveTheLastMoment = NO;
            break;
        } else {
            // app is still active.
            break;
        }
    }
    self.isAppStillActiveTheLastMoment = isSessionActiveTheLastMoment;

    if (!self.isAppStillActiveTheLastMoment) {
        return;
    }

    if (self.backtraceRecordTimes.count == 0 || self.runloopActivitiesTimes.count == 0) {
        return;
    }

    NSTimeInterval lastRunloopActivityTime = [self.runloopActivitiesTimes.lastObject doubleValue];
    NSTimeInterval lastBacktraceTime = [self.backtraceRecordTimes.lastObject doubleValue];
    NSTimeInterval fromLastRunloopActToLastBacktrace = lastBacktraceTime - lastRunloopActivityTime;
    if (fromLastRunloopActToLastBacktrace <= 0) {
        return;
    }

    self.hardStallDurationInSeconds = fromLastRunloopActToLastBacktrace;

    // hard stall captured. (capture main thread running backtrace after the last runloop activity record)
    self.isDuringHardStall = YES;
}

- (NSTimeInterval)lastRunloopAcvitityTime {
    if (self.runloopActivitiesTimes.count == 0)
        return 0;

    return [self.runloopActivitiesTimes.lastObject doubleValue];
}

- (CFRunLoopActivity)lastRunloopActivity {
    if (self.runloopActivities.count == 0)
        return kCFRunLoopEntry;

    return (CFRunLoopActivity)[self.runloopActivities.lastObject integerValue];
}

@end


// MARK: - MTHANRTracingBuffer

static BOOL _tracingBufferRunning = NO;
static MTHANRTracingBufferContext *_context = NULL;
static FILE *_file = NULL;
static size_t _fileSize = 0;
static NSString *_bufferFilePath = NULL;

@interface MTHANRTracingBufferRunner ()
@end

@implementation MTHANRTracingBufferRunner

+ (BOOL)enableTracingBufferAtPath:(NSString *)bufferFilePath {
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

+ (void)readCurrentSessionBufferWithCompletionHandler:(void (^)(MTHANRTracingBuffer *_Nullable))completionHandler {
    if (!completionHandler) return;

    if (!_context) {
        completionHandler(nil);
    } else {
        MTHANRTracingBuffer *buffer = [[MTHANRTracingBuffer alloc] initWithRawContext:_context];
        completionHandler(buffer);
    }
}

+ (void)readPreviousSessionBufferAtPath:(NSString *)bufferFilePath
                      completionHandler:(void (^)(MTHANRTracingBuffer *_Nullable))completionHandler {
    if (!completionHandler) return;

    if (bufferFilePath.length == 0) {
        MTHLogWarn(@"bufferFilePath needed for load previous session buffer.");
        completionHandler(nil);
    } else {
        MTHANRTracingBufferContext context;
        if (mthANRTracingBufferContextFromMmapFile(bufferFilePath, &context)) {
            MTHANRTracingBuffer *buffer = [[MTHANRTracingBuffer alloc] initWithRawContext:&context];
            completionHandler(buffer);
        } else {
            completionHandler(nil);
        }
    }
}

@end
