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

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/mth_stack_backtrace.h>
#import <pthread.h>

@implementation MTHANRDetectThread

- (instancetype)init {
    (self = [super init]);
    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
        self.isMainThreadBlock = NO;
        self.shouldCaptureBackTrace = YES;
        self.thresholdInSeconds = .4f;
        self.name = @"com.meitu.hawkeye.anr.observer";
    }
    return self;
}

- (void)startWithThresholdInSeconds:(double)thresholdInSeconds handler:(MTHANRThreadResultBlock)threadResultBlock {
    self.threadResultBlock = threadResultBlock;
    self.thresholdInSeconds = thresholdInSeconds;
    [self start];
}

- (void)main {
    __block thread_t main_thread;
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        main_thread = mach_thread_self();
    });

    __weak __typeof(self) weakSelf = self;
    while (self.isCancelled == false) {
        _isMainThreadBlock = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf.isMainThreadBlock = false;
                dispatch_semaphore_signal(strongSelf.semaphore);
            }
        });

        BOOL mainThreadBlocked = NO;

        // 减少统计误差，但会增加性能影响 (每次 backtrace 操作在iPhone6s debug 下占用 0.5ms)
        [NSThread sleepForTimeInterval:self.thresholdInSeconds / 4.f];

        double time1 = CFAbsoluteTimeGetCurrent();

        MTHANRRecordRaw *threadStack = nil;
        if (self.isMainThreadBlock) {
            mainThreadBlocked = YES;

            if (self.shouldCaptureBackTrace) {
                threadStack = [[MTHANRRecordRaw alloc] init];
                mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();
                if (stackframes) {
                    // 记录50个有效堆栈
                    mth_stack_backtrace_of_thread(main_thread, stackframes, 50, 0);
                    threadStack->stackframesSize = stackframes->frames_size;
                    threadStack->stackframes = (uintptr_t *)malloc(sizeof(uintptr_t) * stackframes->frames_size);
                    memcpy(threadStack->stackframes, stackframes->frames, sizeof(uintptr_t) * stackframes->frames_size);

                    threadStack->titleFrame = [self titleFrameForStackframes:stackframes->frames size:stackframes->frames_size];

                    mth_free_stack_backtrace(stackframes);
                }
            }
        }
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);

        if (mainThreadBlocked) {
            // the actual duration that the main thread blocked is not equal to (time2 - time1).
            // cause the sleepTimeInterval, the actual duration would be range of
            // (time2 - time1) * 1000.f + 0ms ~ (time2 - time1) * 1000.f + threadSleepTimeInterval.
            double time2 = CFAbsoluteTimeGetCurrent();

            if ((time2 - time1) <= self.thresholdInSeconds * 2.f / 3.f)
                continue;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf.threadResultBlock(time2 - time1, threadStack);
                }
            });
        }
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

@end
