//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/6/29
// Created by: YWH
//


#import "MTHCPUTrace.h"

#import <assert.h>
#import <mach/mach.h>
#import <mach/mach_types.h>
#import <pthread.h>

#import <MTHawkeye/MTHStackFrameSymbolics.h>
#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeSignPosts.h>
#import <MTHawkeye/mth_stack_backtrace.h>

#import "MTHCPUTraceHighLoadRecord.h"


#define MTHCPUTRACE_MAXSTACKCOUNT 50


@interface MTHCPUTrace ()

@property (nonatomic, assign) BOOL isTracing;

@property (nonatomic, strong) NSHashTable<id<MTHCPUTracingDelegate>> *delegates;

@property (nonatomic, strong) dispatch_source_t cpuTracingTimer;
@property (nonatomic, strong) dispatch_queue_t cpuTracingQueue;

@property (nonatomic, assign) CFAbsoluteTime highLoadBeginTime;
@property (nonatomic, assign) NSTimeInterval highLoadLastingTime;

@property (nonatomic, assign) BOOL exceedingHighLoadThreshold;
@property (nonatomic, assign) BOOL exceedingHighLoadLastingLimit;

@property (nonatomic, assign) CFAbsoluteTime highLoadLastingSumUsage;

@property (nonatomic, assign) BOOL ptrToSkipFound;

@end

@implementation MTHCPUTrace {
    std::vector<mth_stack_backtrace *> _cpuHighLoadStackFramesSample;

    MTH_CPUTraceThreadIdAndUsage *_threadIdAndUsageBuffers;
    uint8_t _threadIdAndUsageBuffersLength;

    MTH_CPUTraceStackFramesNode *_rootNode;
    uintptr_t _ptrToSkip;
}

- (void)dealloc {
    if (_threadIdAndUsageBuffers) {
        free(_threadIdAndUsageBuffers);
        _threadIdAndUsageBuffers = nil;
    }

    [self clearStackFramesSample];

    self.cpuTracingQueue = nil;
}

+ (instancetype)shareInstance {
    static MTHCPUTrace *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MTHCPUTrace alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.checkIntervalIdle = 1;
        self.checkIntervalBusy = 0.3;
        self.highLoadLastingLimit = 60;
        self.highLoadThreshold = 0.8;
        self.stackFramesDumpThreshold = 0.15;
        self.ptrToSkipFound = NO;

        self.delegates = [NSHashTable weakObjectsHashTable];

        _threadIdAndUsageBuffersLength = 128;
        _threadIdAndUsageBuffers = (MTH_CPUTraceThreadIdAndUsage *)malloc(sizeof(MTH_CPUTraceThreadIdAndUsage) * _threadIdAndUsageBuffersLength);
    }
    return self;
}

- (void)addDelegate:(id<MTHCPUTracingDelegate>)delegate {
    @synchronized(self.delegates) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<MTHCPUTracingDelegate>)delegate {
    @synchronized(self.delegates) {
        [self.delegates removeObject:delegate];
    }
}

// MARK: -
- (void)startTracing {
    if (!self.cpuTracingQueue) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0);
        self.cpuTracingQueue = dispatch_queue_create("com.meitu.hawkeye.cpu_trace", attr);
    }

    [self changeTimerIntervalTo:self.checkIntervalIdle];
    self.isTracing = YES;
}

- (void)stopTracing {
    [self stopTimerIfNeed];
    self.cpuTracingQueue = nil;
    self.isTracing = NO;
}

- (void)changeTimerIntervalTo:(CGFloat)timerIntervalInSec {
    [self stopTimerIfNeed];

    NSAssert(self.cpuTracingQueue, @"you should init queue firstly");

    self.cpuTracingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.cpuTracingQueue);
    dispatch_source_set_timer(self.cpuTracingTimer, DISPATCH_TIME_NOW, timerIntervalInSec * NSEC_PER_SEC, 0);

    MTHCPUDebugLog("CPU Tracing timer interval %.1lf \n", timerIntervalInSec);

    dispatch_source_set_event_handler(self.cpuTracingTimer, ^{
        @autoreleasepool {
            [self cpuInspectTaskFired];
        }
    });
    dispatch_resume(self.cpuTracingTimer);
}

- (void)stopTimerIfNeed {
    if (self.cpuTracingTimer) {
        dispatch_source_cancel(self.cpuTracingTimer);
        self.cpuTracingTimer = nil;
    }
}

// MARK: -
- (void)resetState {
    self.highLoadBeginTime = 0.f;
    self.highLoadLastingTime = 0.f;
    self.highLoadLastingSumUsage = 0.f;

    self.exceedingHighLoadThreshold = NO;
    self.exceedingHighLoadLastingLimit = NO;

    [self clearStackFramesSample];

    _rootNode = new MTH_CPUTraceStackFramesNode();
}

- (void)clearStackFramesSample {
    if (_cpuHighLoadStackFramesSample.size() != 0) {
        for (auto iter = _cpuHighLoadStackFramesSample.begin(); iter != _cpuHighLoadStackFramesSample.end(); iter++) {
            mth_stack_backtrace *stackframes = (*iter);
            mth_free_stack_backtrace(stackframes);
        }
        _cpuHighLoadStackFramesSample.clear();
    }

    if (_rootNode) {
        _rootNode->resetSubCalls();

        delete _rootNode;
        _rootNode = nil;
    }
}

- (void)cpuInspectTaskFired {
    if (!self.ptrToSkipFound) {
        // skip recording cpu_trace thread.
        mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();
        mth_stack_backtrace_of_thread(mach_thread_self(), stackframes, MTHCPUTRACE_MAXSTACKCOUNT, 0);
        if (stackframes && stackframes->frames_size > 4) {
            _ptrToSkip = stackframes->frames[5];
            self.ptrToSkipFound = YES;
        }

        mth_free_stack_backtrace(stackframes);
    }

    __unused BOOL _inDB = NO;
#if MTH_CPUTraceDebugEnable
    static int debugCount = 0;
    if (++debugCount % 10 == 0)
        _inDB = YES;
    CFAbsoluteTime getAllThreadCPUUsageBegin = CFAbsoluteTimeGetCurrent();
#endif

#if MTH_CPUTracePerformanceEnable
    MTHSignpostStart(530);
#endif

    double cpuUsage = 0.0f;
    unsigned int threadsCount = 0;

    [self getAllThreadCpuUsage:&cpuUsage theadsDetail:_threadIdAndUsageBuffers threadsCount:&threadsCount maxThreadCount:_threadIdAndUsageBuffersLength];

#if MTH_CPUTracePerformanceEnable
    MTHSignpostEnd(530);
#endif

    if (cpuUsage >= self.highLoadThreshold) {
        if (_inDB) MTHCPUDebugLog("\n");
        if (_inDB) MTHCPUDebugLog("CPUTrace get all thread cpu usage, %.3lfms \n", (CFAbsoluteTimeGetCurrent() - getAllThreadCPUUsageBegin) * 1000);

        if (!self.exceedingHighLoadThreshold) {
            [self resetState];

            self.exceedingHighLoadThreshold = YES;

            [self changeTimerIntervalTo:self.checkIntervalBusy];

            self.highLoadBeginTime = CFAbsoluteTimeGetCurrent();
        }

        self.highLoadLastingSumUsage += cpuUsage;

#if MTH_CPUTraceDebugEnable
        CFAbsoluteTime dumpStackFramesTaskBegin = CFAbsoluteTimeGetCurrent();
#endif
#if MTH_CPUTracePerformanceEnable
        MTHSignpostStart(531);
#endif
        [self stackFramesFromThreads:_threadIdAndUsageBuffers
                               count:threadsCount
                   withTotalCPUUsage:cpuUsage];

#if MTH_CPUTracePerformanceEnable
        MTHSignpostEnd(531);
#endif

        double lastingTime = CFAbsoluteTimeGetCurrent() - self.highLoadBeginTime;

        if (_inDB) MTHCPUDebugLog("CPUTrace dump stack frames cost: %.3lfms \n", (CFAbsoluteTimeGetCurrent() - dumpStackFramesTaskBegin) * 1000);
        if (_inDB) MTHCPUDebugLog("CPUTrace high load lasting: %lf, cpu_usage:%.2f \n", lastingTime, cpuUsage);

        if (lastingTime > self.highLoadLastingLimit) {
            self.exceedingHighLoadLastingLimit = YES;
            self.highLoadLastingTime = lastingTime;

#if MTH_CPUTraceDebugEnable
            CFAbsoluteTime highloadRecordUpdateBegin = CFAbsoluteTimeGetCurrent();
#endif

#if MTH_CPUTracePerformanceEnable
            MTHSignpostStart(532);
#endif
            // update stack frame, usage list, lasting time, and notify caller.
            [self generateOrUpdateCPUHighLoadRecord];

#if MTH_CPUTracePerformanceEnable
            MTHSignpostEnd(532);
#endif
            if (_inDB) MTHCPUDebugLog("CPUTrace cpuTraceRecord cost %.3lfms \n", (CFAbsoluteTimeGetCurrent() - highloadRecordUpdateBegin) * 1000);
        }
    } else { // cpuUsage < self.highLoadThreshold

        if (self.exceedingHighLoadLastingLimit && self.exceedingHighLoadThreshold) {
            @synchronized(self.delegates) {
                for (id<MTHCPUTracingDelegate> delegate in self.delegates) {
                    [delegate cpuHighLoadRecordDidEnd];
                }
            }
        }

        BOOL shouldResetToIdleState = self.exceedingHighLoadThreshold;
        if (shouldResetToIdleState) {
            [self resetState];

            [self changeTimerIntervalTo:self.checkIntervalIdle];
        }
    }
}

- (void)stackFramesFromThreads:(MTH_CPUTraceThreadIdAndUsage *)threadInfos
                         count:(uint)threadCount
             withTotalCPUUsage:(double)cpuTotalUsage {
    /*
     performance:
     iPhone6s 10.3.2 release
        avg: 157us
     */

    for (int i = 0; i < threadCount; i++) {
        MTH_CPUTraceThreadIdAndUsage threadInfo = threadInfos[i];

        // only dump stack frames from the thread when the proportion is higher then threshold.
        if ((threadInfo.cpuUsage / cpuTotalUsage) > self.stackFramesDumpThreshold) {
            // get the stack frames of the thread
            mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();
            if (mth_stack_backtrace_of_thread(threadInfo.traceThread, stackframes, MTHCPUTRACE_MAXSTACKCOUNT, 0)) {
                BOOL shouldSkip = NO;
                for (int i = 0; i < stackframes->frames_size; i++) {
                    if (stackframes->frames[i] == _ptrToSkip) {
                        MTHCPUDebugLog("CPUTrace dump stackframe -[%.1lf%%] total-[%.1lf%%] \n", threadInfo.cpuUsage * 100, cpuTotalUsage * 100);
                        shouldSkip = YES;
                        break;
                    }
                }

                if (!shouldSkip) {
                    _cpuHighLoadStackFramesSample.push_back(stackframes);
                } else {
                    mth_free_stack_backtrace(stackframes);
                }
            } else {
                mth_free_stack_backtrace(stackframes);
            }
        }
    }
}

- (void)generateOrUpdateCPUHighLoadRecord {
    for (auto iter = _cpuHighLoadStackFramesSample.begin(); iter != _cpuHighLoadStackFramesSample.end(); iter++) {
        mth_stack_backtrace *stackframes = (*iter);
        MTH_CPUTraceStackFramesNode *curNode = _rootNode;
        int continueCount = 0;
        int size = (int)stackframes->frames_size;
        for (int i = size - 1; i >= 0; i--) {
            // skip system stack frame.
            if (mtha_addr_is_in_sys_libraries(stackframes->frames[i])) {
                continueCount++;
                continue;
            }

            MTH_CPUTraceStackFramesNode *tmpNode = new MTH_CPUTraceStackFramesNode();
            tmpNode->stackframeAddr = stackframes->frames[i];
            tmpNode->calledCount = 0;

            curNode = curNode->addSubCallNode(tmpNode);
            if (curNode->calledCount > 1) {
                delete tmpNode;
            }
        }

        mth_free_stack_backtrace(stackframes);
    }

    _cpuHighLoadStackFramesSample.clear();

    CGFloat averageUsage = (self.highLoadLastingSumUsage / (self.highLoadLastingTime / self.checkIntervalBusy));
    CGFloat lasting = CFAbsoluteTimeGetCurrent() - self.highLoadBeginTime;

    @synchronized(self.delegates) {
        for (id<MTHCPUTracingDelegate> delegate in self.delegates) {
            [delegate cpuHighLoadRecordStartAt:self.highLoadBeginTime
                     didUpdateStackFrameSample:_rootNode
                               averageCPUUsage:averageUsage
                                   lastingTime:lasting];
        }
    }
}

- (void)getAllThreadCpuUsage:(double *)p_totalUsage
                theadsDetail:(MTH_CPUTraceThreadIdAndUsage *)p_threads
                threadsCount:(unsigned int *)p_threadsCount
              maxThreadCount:(uint8_t)maxThreadCount {
    /*
     performance:
     iPhone6s 10.3.2 Release
        avg: 353us (about 30 threads)
     */

    double totalUsageRatio = 0.0;

    thread_info_data_t thinfo;
    thread_act_array_t threads;
    thread_basic_info_t basic_info_t;

    mach_msg_type_number_t count = 0;
    mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;

    if (task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS) {
        for (int idx = 0; idx < count && idx < maxThreadCount; idx++) {
            double cpuUsage = 0.0;
            if (thread_info(threads[idx], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count) == KERN_SUCCESS) {
                basic_info_t = (thread_basic_info_t)thinfo;
                if (!(basic_info_t->flags & TH_FLAGS_IDLE)) {
                    cpuUsage = basic_info_t->cpu_usage / (double)TH_USAGE_SCALE;
                }
            }

            p_threads[idx].traceThread = threads[idx];
            p_threads[idx].cpuUsage = cpuUsage;

            totalUsageRatio += cpuUsage;
        }
        assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t)) == KERN_SUCCESS);
    }
    *p_totalUsage = totalUsageRatio;
    if (p_threadsCount) {
        *p_threadsCount = count;
    }
}

@end
