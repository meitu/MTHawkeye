//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/7/3
// Created by: YWH
//


#import "MTHANRObserver.h"
#import "MTHANRRecord.h"

#import <MTHawkeye/mth_stack_backtrace.h>
#import <pthread.h>


typedef void (^MTHANRThreadResultBlock)(double roughBlockTimeInterval, MTHANRRecordRaw *recordRaw);

@interface MTHAppPingThread : NSThread

@property (atomic, assign) BOOL isMainThreadBlock;
@property (nonatomic, assign) BOOL shouldCaptureBackTrace;
@property (nonatomic, assign) double thresholdInSeconds;
@property (nonatomic, copy) MTHANRThreadResultBlock threadResultBlock;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end


@implementation MTHAppPingThread

- (instancetype)init {
    self = [super init];
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
                mth_stack_backtrace *stackframes = (mth_stack_backtrace *)malloc(sizeof(mth_stack_backtrace));
                mth_stack_backtrace_of_thread(main_thread, stackframes, sizeof(mth_stack_backtrace), 0);
                threadStack->stackframes = stackframes->frames;
                threadStack->stackframesSize = stackframes->frames_size;
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

@end


/****************************************************************************/
#pragma mark -


@interface MTHANRObserver ()

@property (nonatomic, copy) MTHANRObserveResultHandler detectedHandler;
@property (nonatomic, strong) MTHAppPingThread *pingThread;

@end

@implementation MTHANRObserver

- (void)dealloc {
    [self.pingThread cancel];
}

- (instancetype)initWithObserveResultHandler:(MTHANRObserveResultHandler)detectedHandler {
    self = [super init];
    if (self) {
        self.detectedHandler = detectedHandler;
    }
    return self;
}

- (BOOL)isRunning {
    if (!self.pingThread) {
        return false;
    }
    return !self.pingThread.isCancelled;
}

- (void)setShouldCaptureBackTrace:(BOOL)shouldCaptureBackTrace {
    _shouldCaptureBackTrace = shouldCaptureBackTrace;
    self.pingThread.shouldCaptureBackTrace = shouldCaptureBackTrace;
}

- (void)startWithThresholdInSeconds:(double)thresholdInSeconds {
    self.pingThread = [[MTHAppPingThread alloc] init];
    self.pingThread.shouldCaptureBackTrace = self.shouldCaptureBackTrace;
    __weak typeof(self) weakSelf = self;
    [self.pingThread
        startWithThresholdInSeconds:thresholdInSeconds
                            handler:^(double roughBlockTimeInterval, MTHANRRecordRaw *recordRaw) {
                                if (weakSelf) {
                                    recordRaw.time = [[NSDate new] timeIntervalSince1970];
                                    recordRaw.duration = roughBlockTimeInterval;
                                    weakSelf.detectedHandler(weakSelf, recordRaw);
                                }
                            }];
}

- (void)stop {
    [self.pingThread cancel];
    self.pingThread = nil;
}

@end
