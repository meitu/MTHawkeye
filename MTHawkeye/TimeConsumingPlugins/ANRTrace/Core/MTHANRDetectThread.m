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

@interface MTHANRDetectThread () {
    pthread_mutex_t _curStallingRunloopsMutex;
}

@property (nonatomic, assign) float annealingStepInMS;
@property (nonatomic, assign) NSInteger annealingStepCount;

@property (nonatomic, assign) CFRunLoopObserverRef highPriorityObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef lowPriorityObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef highPriorityInitObserverRef;
@property (nonatomic, assign) CFRunLoopObserverRef lowPriorityInitObserverRef;

@property (atomic, assign) BOOL runloopWorking;

@property (atomic, assign) NSTimeInterval curRunloopStartFrom;
@property (atomic, assign) NSTimeInterval curRunloopEndAt;

@property (atomic, assign) NSTimeInterval enterBackgroundNotifyTime;
@property (atomic, assign) UIApplicationState appState;

@property (nonatomic, strong) NSMutableArray<MTHANRRecord *> *curStallingRunloops;
@property (nonatomic, strong) NSMutableArray<MTHANRMainThreadStallingSnapshot *> *stallingSnapshots;

@property (nonatomic, assign) float stallingThreshold;
@property (nonatomic, assign) float detectInterval;

@end


@implementation MTHANRDetectThread

- (void)dealloc {
}

- (instancetype)init {
    (self = [super init]);
    if (self) {
        self.shouldCaptureBackTrace = YES;
        self.detectInterval = 0.1f;
        self.stallingThreshold = 0.4f;
        self.annealingStepInMS = 200;
        self.annealingStepCount = 1;
        self.name = @"com.meitu.hawkeye.anr.observer";
    }
    return self;
}

- (void)startWithDetectInterval:(float)detectInterval anrThreshold:(float)stallingThreshold handler:(MTHANRThreadResultBlock)threadResultBlock {
    if ([@(stallingThreshold) compare:@(detectInterval)] != NSOrderedDescending) {
        NSAssert(0, @"Detect Interval should be less than ANR Threshold");
    }

    self.threadResultBlock = threadResultBlock;
    self.detectInterval = detectInterval;
    self.stallingThreshold = stallingThreshold;
    self.curRunloopStartFrom = 0;
    self.curRunloopEndAt = 0;

    self.stallingSnapshots = [NSMutableArray array];
    self.curStallingRunloops = [NSMutableArray array];

    [self start];
}

#pragma mark - Thread Work
- (void)start {
    pthread_mutex_init(&_curStallingRunloopsMutex, NULL);

    [self registerObserver];
    [self registerNotification];

    [super start];
}

- (void)cancel {
    [super cancel];
    [self unregisterObserver];
    [self unregisterNotification];
    [self.stallingSnapshots removeAllObjects];

    pthread_mutex_destroy(&_curStallingRunloopsMutex);
}

- (void)main {
    __block thread_t main_thread;
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        main_thread = mach_thread_self();
    });

    while (self.isCancelled == false) {
        NSTimeInterval now = [MTHawkeyeUtility currentTime];
        NSTimeInterval curRunloopStartFrom = self.curRunloopStartFrom;

        MTHANRMainThreadStallingSnapshot *stallingMainBacktrace = nil;

        BOOL isStalling = ((now - curRunloopStartFrom) >= self.stallingThreshold);
        if (isStalling) {
            if (self.appState == UIApplicationStateBackground) {
                if (self.enterBackgroundNotifyTime != 0) {
                    NSTimeInterval backgroundRunningTime = now - self.enterBackgroundNotifyTime;
                    if (backgroundRunningTime > 175) {
                        [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityBackgroundTaskWillOutOfTime];
                        MTHLogWarn(@"background task will run out of time");
                    }

                    usleep(self.detectInterval * 1000 * 1000);
                } else {
                    MTHLogWarn(@"in background, but main thread still stalling.");
                }
            }

            stallingMainBacktrace = [self snapshotThreadBacktrace:main_thread];

            // annealing if needed, record stalling snapshot if need.
            {
                MTHANRMainThreadStallingSnapshot *preStallingMainBacktrace = self.stallingSnapshots.lastObject;
                if (preStallingMainBacktrace && stallingMainBacktrace) {
                    // annealing while stalling on the same backtrace.
                    if (preStallingMainBacktrace->titleFrame != stallingMainBacktrace->titleFrame) {
                        [self.stallingSnapshots addObject:stallingMainBacktrace];
                        self.annealingStepCount = 1;
                    } else {
                        self.annealingStepCount += 1;
                    }
                } else {
                    self.annealingStepCount = 1;

                    if (stallingMainBacktrace)
                        [self.stallingSnapshots addObject:stallingMainBacktrace];
                }
            }
        }

        // need to deal with stalling record.
        NSArray<MTHANRRecord *> *curStallingRecords = [self dequeueAllStallingRunloopRecords];
        if (curStallingRecords.count > 0) {
            if (self.shouldCaptureBackTrace && self.threadResultBlock) {
                for (MTHANRRecord *record in curStallingRecords) {
                    NSMutableArray *matchedSnapshot = [NSMutableArray array];
                    NSMutableArray *snapshotsOutOfDate = [NSMutableArray array];
                    for (MTHANRMainThreadStallingSnapshot *snapshot in self.stallingSnapshots) {
                        if (snapshot.time > record.startFrom && snapshot.time <= (record.startFrom + record.durationInSeconds)) {
                            [matchedSnapshot addObject:snapshot];
                        } else if (snapshot.time < record.startFrom) {
                            [snapshotsOutOfDate addObject:snapshot];
                        }
                    }
                    if (matchedSnapshot.count > 0) {
                        record.stallingSnapshots = [matchedSnapshot copy];
                        [self.stallingSnapshots removeObjectsInArray:record.stallingSnapshots];
                    }
                    if (snapshotsOutOfDate) {
                        [self.stallingSnapshots removeObjectsInArray:snapshotsOutOfDate];
                    }

                    self.threadResultBlock(record);
#if _MTHawkeyeANRTracingDebugEnabled
                    MTHLogInfo(@"ANR event captured: \n%@", record);
#endif
                }
            }
        }

        if (isStalling) {
            usleep(self.detectInterval * 1000 * 1000 + (self.annealingStepCount - 1) * self.annealingStepInMS * 1000);
        } else {
            usleep(self.detectInterval * 1000 * 1000);
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

- (MTHANRMainThreadStallingSnapshot *)snapshotThreadBacktrace:(thread_t)thread {
    MTHANRMainThreadStallingSnapshot *threadStack = nil;
    threadStack = [[MTHANRMainThreadStallingSnapshot alloc] init];
    threadStack.cpuUsed = MTHawkeyeAppStat.cpuUsedByAllThreads * 100.0f;
    threadStack.time = [MTHawkeyeUtility currentTime];
    mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();

    if (stackframes) {
        mth_stack_backtrace_of_thread(thread, stackframes, MTHANRTRACE_MAXSTACKCOUNT, 0);
        threadStack->stackframesSize = stackframes->frames_size;
        threadStack->stackframes = (uintptr_t *)malloc(sizeof(uintptr_t) * stackframes->frames_size);
        if (stackframes->frames) {
            memcpy(threadStack->stackframes, stackframes->frames, sizeof(uintptr_t) * stackframes->frames_size);
            threadStack->titleFrame = [self titleFrameForStackframes:stackframes->frames size:stackframes->frames_size];

            [MTHANRTracingBufferRunner traceStackBacktrace:stackframes];
        }
        mth_free_stack_backtrace(stackframes);
    }

    return threadStack;
}

- (void)enqueueNewRunloopStalling:(MTHANRRecord *)anrRecord {
    pthread_mutex_lock(&_curStallingRunloopsMutex);
    [self.curStallingRunloops addObject:anrRecord];
    pthread_mutex_unlock(&_curStallingRunloopsMutex);
}

- (NSArray<MTHANRRecord *> *)dequeueAllStallingRunloopRecords {
    pthread_mutex_lock(&_curStallingRunloopsMutex);

    NSArray *result = [self.curStallingRunloops copy];
    [self.curStallingRunloops removeAllObjects];

    pthread_mutex_unlock(&_curStallingRunloopsMutex);
    return result;
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

                        [MTHANRTracingBufferRunner traceAppLifeActivity:activity];

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

static BOOL trySkippingHeaderActivitiesBeforeEnterForeground = NO;
static BOOL skipedHeaderActivitiesBeforeEnterForeground = NO;
static NSTimeInterval preActivityTimeBeforeEnterForeground = 0;
static NSTimeInterval intervalBetweenLastTwoActivitiesBeforeEnterForeground = 0;

static void resetSkipHeaderActivitiesBeforeEnterForegroundFlags(void) {
    trySkippingHeaderActivitiesBeforeEnterForeground = NO;
    preActivityTimeBeforeEnterForeground = 0;
    intervalBetweenLastTwoActivitiesBeforeEnterForeground = 0;

#if _MTHawkeyeANRTracingDebugEnabled
    MTHLogInfo(@"ANR suspended runloop fix, reset");
#endif
}

static BOOL skipHeaderActivitiesBeforeEnterForegroundIfNeeded(MTHANRDetectThread *object) {
    // fix the wrong startFrom while suspend in the background.

    if (skipedHeaderActivitiesBeforeEnterForeground) {
        return NO;
    }

    BOOL result = NO;
    trySkippingHeaderActivitiesBeforeEnterForeground = YES;
    if (preActivityTimeBeforeEnterForeground == 0) {
        preActivityTimeBeforeEnterForeground = object.curRunloopStartFrom;
#if _MTHawkeyeANRTracingDebugEnabled
        MTHLogInfo(@"ANR suspended runloop fix, start %@", @(preActivityTimeBeforeEnterForeground));
#endif
    }

    NSTimeInterval curTime = [MTHawkeyeUtility currentTime];
    NSTimeInterval diff = curTime - preActivityTimeBeforeEnterForeground;

#if _MTHawkeyeANRTracingDebugEnabled
    MTHLogInfo(@"ANR suspended runloop fix, diff: %.3fms, curTime: %.3f", diff * 1000, curTime);
#endif

    if (intervalBetweenLastTwoActivitiesBeforeEnterForeground <= DBL_EPSILON) {
        intervalBetweenLastTwoActivitiesBeforeEnterForeground = diff;
    } else {
        // while the first increased sharply. move forward the `curRunloopStartFrom`.
        // in case that `curRunloopStartFrom` is dirty (time before App suspended, it should be time after App suspended)
        if (diff / intervalBetweenLastTwoActivitiesBeforeEnterForeground > 10 && diff > 0.1) {
#if _MTHawkeyeANRTracingDebugEnabled
            MTHLogInfo(@"ANR suspended runloop fix: found sharply increasing: %@", @(diff / intervalBetweenLastTwoActivitiesBeforeEnterForeground));
            MTHLogInfo(@"ANR suspended runloop fix: And move `StartFrom` from:%@ to:%@ ", @(object.curRunloopStartFrom), @(curTime));
#endif
            skipedHeaderActivitiesBeforeEnterForeground = YES;
            trySkippingHeaderActivitiesBeforeEnterForeground = NO;
            object.curRunloopStartFrom = curTime;
            result = YES;
        }

        if (diff > intervalBetweenLastTwoActivitiesBeforeEnterForeground)
            intervalBetweenLastTwoActivitiesBeforeEnterForeground = diff;
    }
    preActivityTimeBeforeEnterForeground = curTime;

    return result;
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
            BOOL shouldTrace = NO;
            if (observer == object.highPriorityInitObserverRef || object.runloopWorking == NO) {
                object.curRunloopStartFrom = [MTHawkeyeUtility currentTime];
                shouldTrace = YES;

                if (trySkippingHeaderActivitiesBeforeEnterForeground) {
                    resetSkipHeaderActivitiesBeforeEnterForegroundFlags();
                }
            } else if (object.enterBackgroundNotifyTime != 0 || trySkippingHeaderActivitiesBeforeEnterForeground) {
                skipHeaderActivitiesBeforeEnterForegroundIfNeeded(object);
            }

#if _MTHawkeyeANRTracingDebugEnabled
            // MTHLogInfo(@"%@", mthStringFromRunloopActivity(activity));
            [MTHANRTracingBufferRunner traceRunloopActivity:activity];
#else
            if (shouldTrace)
                [MTHANRTracingBufferRunner traceRunloopActivity:activity];
#endif

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
            BOOL shouldTrace = NO;
            if (object.runloopWorking) {
                object.runloopWorking = NO;
                NSTimeInterval runloopEndAt = [MTHawkeyeUtility currentTime];
                shouldTrace = YES;

                NSTimeInterval runloopStartFrom = object.curRunloopStartFrom;
                if (runloopStartFrom > 0 && (runloopEndAt - runloopStartFrom) > object.stallingThreshold) {
                    MTHANRRecord *record = [[MTHANRRecord alloc] init];
                    record.startFrom = runloopStartFrom;
                    record.durationInSeconds = runloopEndAt - runloopStartFrom;
                    [object enqueueNewRunloopStalling:record];
                }
            }

            if (trySkippingHeaderActivitiesBeforeEnterForeground) {
                resetSkipHeaderActivitiesBeforeEnterForegroundFlags();
            }

#if _MTHawkeyeANRTracingDebugEnabled
            // MTHLogInfo(@"%@", mthStringFromRunloopActivity(activity));
            [MTHANRTracingBufferRunner traceRunloopActivity:activity];
#else
            if (shouldTrace)
                [MTHANRTracingBufferRunner traceRunloopActivity:activity];
#endif

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
