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
#import "MTHANRTracingBuffer.h"

#import <MTHawkeye/MTHawkeyeAppStat.h>
#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeUtility.h>
#import <MTHawkeye/mth_stack_backtrace.h>

#import <errno.h>
#import <pthread.h>

#define MTHANRTRACE_MAXSTACKCOUNT 50

@interface MTHANRDetectThread ()

@property (nonatomic, assign) float annealingStepInMS;

@property (nonatomic, assign) CFRunLoopObserverRef highPriorityObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef lowPriorityObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef highPriorityInitObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef lowPriorityInitObserverRef;

@property (atomic, assign) BOOL runloopWorking;

@property (atomic, assign) NSTimeInterval runloopEventTime;
@property (atomic, assign) NSTimeInterval runloopCycleStopTime;
@property (atomic, assign) NSTimeInterval enterBackgroundNotifyTime;
@property (atomic, assign) UIApplicationState appState;

@property (nonatomic, assign) NSTimeInterval anrStartTime;
@property (nonatomic, strong) NSMutableArray<MTHANRRecordRaw *> *threadStacks;
@property (nonatomic, assign) float anrThreshold;
@property (nonatomic, assign) float detectInterval;

@end


@implementation MTHANRDetectThread

- (instancetype)init {
    (self = [super init]);
    if (self) {
        self.shouldCaptureBackTrace = YES;
        self.detectInterval = 0.1f;
        self.anrThreshold = 0.4f;
        self.annealingStepInMS = 200;
        self.name = @"com.meitu.hawkeye.anr.observer";
        self.threadStacks = [NSMutableArray array];
    }
    return self;
}

- (void)startWithDetectInterval:(float)detectInterval anrThreshold:(float)anrThreshold handler:(MTHANRThreadResultBlock)threadResultBlock {
    if ([@(anrThreshold) compare:@(detectInterval)] != NSOrderedDescending) {
        NSAssert(0, @"Detect Interval should be less than ANR Threshold");
    }

    self.threadResultBlock = threadResultBlock;
    self.detectInterval = detectInterval;
    self.anrThreshold = anrThreshold;
    self.runloopEventTime = 0;
    [self start];
}

#pragma mark - Thread Work
- (void)start {
    [self registerObserver];
    [self registerNotification];
    [super start];
}

- (void)cancel {
    [super cancel];
    [self unregisterObserver];
    [self unregisterNotification];
    [self.threadStacks removeAllObjects];
}

- (void)main {
    __block thread_t main_thread;
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        main_thread = mach_thread_self();
    });

    while (self.isCancelled == false) {
        NSTimeInterval current = [MTHawkeyeUtility currentTime];
        NSTimeInterval runloopCycleStartTime = self.runloopEventTime;
        float diff = current - runloopCycleStartTime;
        BOOL anrDetected = NO;
        if (diff >= self.anrThreshold && current > runloopCycleStartTime) {
            if (self.appState == UIApplicationStateBackground) {
                if (self.enterBackgroundNotifyTime != 0) {
                    NSTimeInterval backgroundRunningTime = current - self.enterBackgroundNotifyTime;
                    if (backgroundRunningTime > 175) {
                        [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityBackgroundTaskWillOutOfTime];
                        MTHLogWarn(@"background task will run out of time");
                    }

                    usleep(self.detectInterval * 1000 * 1000);
                    continue;
                } else {
                    MTHLogWarn(@"in background, but main thread still stalling.");
                }
            }

            anrDetected = YES;
            [self.threadStacks addObject:[self recordThreadStack:main_thread]];
        }

        if (anrDetected || self.anrStartTime != 0) {
            self.anrStartTime = self.anrStartTime == 0 ? runloopCycleStartTime : self.anrStartTime;

            // ANR is happening, wait for next normal one to report
            if (self.anrStartTime == runloopCycleStartTime) {
                usleep(self.detectInterval * 1000 * 1000 + (self.threadStacks.count - 1) * self.annealingStepInMS * 1000);
                continue;
            }

            if (self.shouldCaptureBackTrace && self.threadResultBlock) {
                MTHANRRecord *record = [[MTHANRRecord alloc] init];
                record.rawRecords = [NSArray arrayWithArray:self.threadStacks];
                record.duration = runloopCycleStartTime - self.anrStartTime;
                self.threadResultBlock(record);
            }

            [self.threadStacks removeAllObjects];
            self.anrStartTime = 0;
        }

        usleep(self.detectInterval * 1000 * 1000);
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
        if (stackframes->frames) {
            memcpy(threadStack->stackframes, stackframes->frames, sizeof(uintptr_t) * stackframes->frames_size);
            threadStack->titleFrame = [self titleFrameForStackframes:stackframes->frames size:stackframes->frames_size];

            [MTHANRTracingBuffer traceStackBacktrace:stackframes];
        }
        mth_free_stack_backtrace(stackframes);
    }

    return threadStack;
}

#pragma mark - Notifications
- (void)registerNotification {
    NSArray *appNotice = @[
        UIApplicationWillEnterForegroundNotification,
        @(MTHawkeyeAppLifeActivityWillEnterForeground),
        UIApplicationWillTerminateNotification,
        @(MTHawkeyeAppLifeActivityWillTerminate),
        UIApplicationDidBecomeActiveNotification,
        @(MTHawkeyeAppLifeActivityDidBecomeActive),
        UIApplicationDidEnterBackgroundNotification,
        @(MTHawkeyeAppLifeActivityDidEnterBackground),
        UIApplicationWillResignActiveNotification,
        @(MTHawkeyeAppLifeActivityWillResignActive),
        UIApplicationDidReceiveMemoryWarningNotification,
        @(MTHawkeyeAppLifeActivityMemoryWarning),
    ];

    for (NSInteger i = 0; i < appNotice.count; i += 2) {
        NSString *noticeName = appNotice[i];
        MTHawkeyeAppLifeActivity activity = [appNotice[i + 1] integerValue];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:noticeName
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *_Nonnull note) {
                        self.appState = [UIApplication sharedApplication].applicationState;

                        [MTHANRTracingBuffer traceAppLifeActivity:activity];

                        if (activity == MTHawkeyeAppLifeActivityDidEnterBackground) {
                            self.enterBackgroundNotifyTime = [MTHawkeyeUtility currentTime];
                        } else if (activity == MTHawkeyeAppLifeActivityDidBecomeActive) {
                            self.enterBackgroundNotifyTime = 0;
                        }
                    }];
    }
}

- (void)unregisterNotification {
    NSArray *appNotice = @[
        UIApplicationWillEnterForegroundNotification,
        UIApplicationWillTerminateNotification,
        UIApplicationDidBecomeActiveNotification,
        UIApplicationDidEnterBackgroundNotification,
        UIApplicationWillResignActiveNotification,
        UIApplicationDidReceiveMemoryWarningNotification,
    ];
    for (NSString *noticeName in appNotice) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:noticeName object:nil];
    }
}

#pragma mark - Runloop Observer
static void mthanr_runLoopHighPriorityObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    MTHANRDetectThread *object = (__bridge MTHANRDetectThread *)info;

    switch (activity) {
        case kCFRunLoopEntry:
        case kCFRunLoopBeforeTimers:
        case kCFRunLoopBeforeSources:
        case kCFRunLoopAfterWaiting: {
            // UIInitializationRunLoopMode just call once, so that should detect each step
            if (observer == object.highPriorityInitObserverRef || object.runloopWorking == NO) {
                object.runloopEventTime = [MTHawkeyeUtility currentTime];
            }

            [MTHANRTracingBuffer traceRunloopActivity:activity];

            object.runloopWorking = YES;
            break;
        }
        default:
            break;
    }
}

static void mthanr_lowPriorityObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    MTHANRDetectThread *object = (__bridge MTHANRDetectThread *)info;
    switch (activity) {
        case kCFRunLoopBeforeWaiting:
        case kCFRunLoopExit: {
            if (object.runloopWorking) {
                object.runloopWorking = NO;
            }

            [MTHANRTracingBuffer traceRunloopActivity:activity];

            break;
        }
        default:
            break;
    }
}

- (void)registerObserver {
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};

    if (!self.highPriorityObserverRef) {
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MIN, &mthanr_runLoopHighPriorityObserverCallBack, &context);
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
        self.highPriorityObserverRef = observer;
    }

    if (!self.lowPriorityObserverRef) {
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MAX, &mthanr_lowPriorityObserverCallBack, &context);
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
        self.lowPriorityObserverRef = observer;
    }

    if (!self.highPriorityInitObserverRef) {
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MIN, &mthanr_runLoopHighPriorityObserverCallBack, &context);
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, (CFRunLoopMode) @"UIInitializationRunLoopMode");
        self.highPriorityInitObserverRef = observer;
    }

    if (!self.lowPriorityInitObserverRef) {
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MAX, &mthanr_lowPriorityObserverCallBack, &context);
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, (CFRunLoopMode) @"UIInitializationRunLoopMode");
        self.lowPriorityInitObserverRef = observer;
    }
}

- (void)unregisterObserver {
    if (self.highPriorityObserverRef) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.highPriorityObserverRef, kCFRunLoopCommonModes);
        CFRelease(self.highPriorityObserverRef);
        self.highPriorityObserverRef = NULL;
    }

    if (self.lowPriorityObserverRef) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.lowPriorityObserverRef, kCFRunLoopCommonModes);
        CFRelease(self.lowPriorityObserverRef);
        self.lowPriorityObserverRef = NULL;
    }

    if (self.highPriorityInitObserverRef) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.highPriorityInitObserverRef, (CFRunLoopMode) @"UIInitializationRunLoopMode");
        CFRelease(self.highPriorityInitObserverRef);
        self.highPriorityInitObserverRef = NULL;
    }

    if (self.lowPriorityInitObserverRef) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.lowPriorityInitObserverRef, (CFRunLoopMode) @"UIInitializationRunLoopMode");
        CFRelease(self.lowPriorityInitObserverRef);
        self.lowPriorityInitObserverRef = NULL;
    }
}

@end
