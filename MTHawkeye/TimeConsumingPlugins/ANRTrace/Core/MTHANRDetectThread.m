//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/6/14
// Created by: David.Dai
//

#import "MTHANRDetectThread.h"

#import <MTHawkeye/MTHawkeyeAppStat.h>
#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/mth_stack_backtrace.h>
#import <pthread.h>

#define MTHANRTRACE_MAXSTACKCOUNT 50

@interface MTHANRDetectThread ()
@property (nonatomic, assign) float runloopTimeOutInterval;
@property (nonatomic, assign) CFRunLoopObserverRef observerRef;
@property (atomic, assign) CFAbsoluteTime lastCallbackTime;
@property (atomic, assign) CFAbsoluteTime callbackTime;
@property (atomic, assign) BOOL runloopDetectable;
@property (nonatomic, strong) NSMutableArray<MTHANRRecordRaw *> *threadStacks;
@end

@implementation MTHANRDetectThread

- (instancetype)init {
    (self = [super init]);
    if (self) {
        self.shouldCaptureBackTrace = YES;
        self.thresholdInSeconds = 1.0f;
        self.runloopTimeOutInterval = 1.5f;
        self.name = @"com.meitu.hawkeye.anr.observer";
        self.threadStacks = [NSMutableArray array];
    }
    return self;
}

- (void)startWithThresholdInSeconds:(double)thresholdInSeconds handler:(MTHANRThreadResultBlock)threadResultBlock {
    self.threadResultBlock = threadResultBlock;
    self.thresholdInSeconds = thresholdInSeconds;
    [self start];
}

#pragma mark - Thread Work
- (void)start {
    [self registerObserver];
    [super start];
}

- (void)cancel {
    [super cancel];
    [self unregisterObserver];
    [self.threadStacks removeAllObjects];
}

- (void)main {
    __block thread_t main_thread;
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        main_thread = mach_thread_self();
    });

    while (self.isCancelled == false) {
        // 记录当前堆栈
        [self.threadStacks addObject:[self recordThreadStack:main_thread]];

        // runloop比检测回调还慢，可能发生了ANR等下一次runloop回来再判断
        if (!self.runloopDetectable) {
            self.runloopDetectable = NO;
            usleep(self.thresholdInSeconds * 1000 * 1000);
            continue;
        }

        float runloopInSecond = self.callbackTime - self.lastCallbackTime;
        BOOL runloopTimeout = runloopInSecond >= self.runloopTimeOutInterval;
        if (runloopTimeout) {
            if (self.shouldCaptureBackTrace && self.threadResultBlock) {
                MTHANRRecord *record = [[MTHANRRecord alloc] init];
                record.rawRecords = [NSArray arrayWithArray:self.threadStacks];
                record.duration = runloopInSecond;
                self.threadResultBlock(record);
            }
        }

        [self.threadStacks removeAllObjects];
        self.runloopDetectable = NO;
        usleep(self.thresholdInSeconds * 1000 * 1000);
    }
}

- (uintptr_t)titleFrameForStackframes:(uintptr_t *)frames size:(size_t)size {
    for (int fi = 0; fi < size; ++fi) {
        uintptr_t frame = frames[fi];
        if (!mtha_addr_is_in_sys_libraries(frame)) {
            return frame;
        }
    }

    if (size > 0) {
        uintptr_t frame = frames[0];
        return frame;
    }
    return 0;
}

- (MTHANRRecordRaw *)recordThreadStack:(thread_t)thread {
    MTHANRRecordRaw *threadStack = nil;
    threadStack = [[MTHANRRecordRaw alloc] init];
    threadStack.cpuUsed = MTHawkeyeAppStat.cpuUsedByAllThreads * 100.0f;
    threadStack.time = [[NSDate new] timeIntervalSince1970];
    mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();

    if (stackframes) {
        mth_stack_backtrace_of_thread(thread, stackframes, MTHANRTRACE_MAXSTACKCOUNT, 0);
        threadStack->stackframesSize = stackframes->frames_size;
        threadStack->stackframes = (uintptr_t *)malloc(sizeof(uintptr_t) * stackframes->frames_size);
        memcpy(threadStack->stackframes, stackframes->frames, sizeof(uintptr_t) * stackframes->frames_size);
        threadStack->titleFrame = [self titleFrameForStackframes:stackframes->frames size:stackframes->frames_size];
        mth_free_stack_backtrace(stackframes);
    }

    return threadStack;
}

#pragma mark - Runloop Observer
static void mthanr_runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    MTHANRDetectThread *object = (__bridge MTHANRDetectThread *)info;
    object.runloopDetectable = YES;
    if (object.callbackTime == 0) {
        object.callbackTime = CFAbsoluteTimeGetCurrent();
        object.lastCallbackTime = object.callbackTime;
        return;
    }

    object.lastCallbackTime = object.callbackTime;
    object.callbackTime = CFAbsoluteTimeGetCurrent();
}

- (void)registerObserver {
    if (self.observerRef) {
        return;
    }

    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
        kCFRunLoopAfterWaiting,
        YES,
        0,
        &mthanr_runLoopObserverCallBack,
        &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    self.observerRef = observer;
}

- (void)unregisterObserver {
    if (!self.observerRef) {
        return;
    }

    CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.observerRef, kCFRunLoopCommonModes);
    CFRelease(self.observerRef);
    self.observerRef = NULL;
}
@end
