//
//  MTHBackgroundTaskTraceAdaptor.m
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/22.
//

#import "MTHBackgroundTaskTraceAdaptor.h"
#import "MTHBackgroundTaskObserver.h"
#import "MTHBackgroundTaskStoreInfo.h"
#import "MTHawkeyeDyldImagesUtils.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+BackgroundTaskTrace.h"
#import "MTHawkeyeUtility.h"
#import "mth_stack_backtrace.h"

@interface MTHBackgroundTaskTraceAdaptor () <MTHBackgroundTaskObserverProcessDelegate>

@property (nonatomic, strong) dispatch_source_t backgroundTaskRecordTimer;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskRecordQueue;
@property (nonatomic, strong) MTHBackgroundTaskStoreInfo *tracingData;

@property (assign, nonatomic) NSUInteger recordedStartTasksCount;
@property (assign, nonatomic) NSUInteger recordedEndTasksCount;

@end

@implementation MTHBackgroundTaskTraceAdaptor

+ (nonnull NSString *)pluginID {
    return @"background-task-trace";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].backgroundTaskTraceOn) {
        return;
    }

    MTHLogInfo(@"background task trace start");

    [self observeSettings];
    [self observeAppEnterBackground];

    if (![MTHBackgroundTaskObserver isEnabled]) {
        [MTHBackgroundTaskObserver setEnabled:YES];
    }

    self.tracingData = [[MTHBackgroundTaskStoreInfo alloc] init];

    [MTHBackgroundTaskObserver setMTHBackgroundTaskObserverProcessDelegate:self];

    self.recordedStartTasksCount = 0;
    self.recordedEndTasksCount = 0;

    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0);
    self.backgroundTaskRecordQueue = dispatch_queue_create("com.meitu.kawkeye.backgroundTask_trace", attr);
    self.backgroundTaskRecordTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.backgroundTaskRecordQueue);
    dispatch_source_set_timer(self.backgroundTaskRecordTimer, DISPATCH_TIME_NOW, 3.0f * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(self.backgroundTaskRecordTimer, ^{
        @autoreleasepool {
            [self writeBackgroundTaskRecordsToFile];
        }
    });

    dispatch_resume(self.backgroundTaskRecordTimer);
}

- (void)hawkeyeClientDidStop {
    [MTHBackgroundTaskObserver setMTHBackgroundTaskObserverProcessDelegate:nil];

    self.tracingData = nil;

    if ([MTHBackgroundTaskObserver isEnabled]) {
        [MTHBackgroundTaskObserver setEnabled:NO];
    }

    [self unObserveSettings];
    [self unObserveAppEnterBackground];

    dispatch_source_cancel(self.backgroundTaskRecordTimer);
    self.backgroundTaskRecordTimer = nil;
    self.backgroundTaskRecordQueue = nil;

    MTHLogInfo(@"background task trace stop");
}

- (void)observeSettings {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(backgroundTaskTraceOn))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            if ([newValue boolValue]) {
                                                [weakSelf hawkeyeClientDidStart];
                                            } else {
                                                [weakSelf hawkeyeClientDidStop];
                                            }
                                        }];
}

- (void)unObserveSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(backgroundTaskTraceOn))];
}

- (void)observeAppEnterBackground {
    __weak __typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf writeBackgroundTaskRecordsToFile];
                                                      });
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf writeBackgroundTaskRecordsToFile];
                                                      });
                                                  }];
}

- (void)unObserveAppEnterBackground {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (void)writeBackgroundTaskRecordsToFile {
    NSDictionary *backgroundTasks = [self.tracingData backgroundTasks];
    if (backgroundTasks.count == 0) {
        return;
    }

    if (self.recordedStartTasksCount == self.tracingData.recordedStartTaskCount && self.recordedEndTasksCount == self.tracingData.recordedEndTasksCount) {
        return;
    }
    self.recordedStartTasksCount = self.tracingData.recordedStartTaskCount;
    self.recordedEndTasksCount = self.tracingData.recordedEndTasksCount;

    NSString *beginDate = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility appLaunchedTime])];
    NSString *endDate = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];

    NSMutableDictionary *valueDict = @{}.mutableCopy;
    valueDict[@"begin_date"] = beginDate;
    valueDict[@"end_date"] = endDate;
    valueDict[@"backgroundTasks"] = backgroundTasks;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:valueDict.copy options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn(@"store vc will dealloc failed: %@", error.localizedDescription);
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"backgroundTasks.mtlog"];
        dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
            [jsonData writeToFile:path options:NSDataWritingAtomic error:nil];
        });
    }
}

// MAKR: - record
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

- (void)processBeginBackgroundTask:(NSUInteger)identifierID taskName:(NSString *)name {
    MTHBackgroundTaskInfo *info = [[MTHBackgroundTaskInfo alloc] init];
    info.taskName = name;
    info.identifierID = identifierID;

    mth_stack_backtrace *stackframes = mth_malloc_stack_backtrace();

    if (stackframes) {
        const int kMaxStackFrame = 20; // only care about the top 20 frames.
        // skip the top 5 frame (mach_msg_trap, mach_msg, thread_get_state, mth_stack_backtrace_of_thread, processBeginBackgroundTask:taskName:)
        mth_stack_backtrace_of_thread(mach_thread_self(), stackframes, kMaxStackFrame, 5);
        info->stackframesSize = stackframes->frames_size;
        [info setStackFrames:stackframes->frames stackframesSize:stackframes->frames_size];
        info->titleFrame = [self titleFrameForStackframes:stackframes->frames size:stackframes->frames_size];

        mth_free_stack_backtrace(stackframes);
    }

    [self.tracingData syncAddBackgroundTask:info];
}

- (void)processEndBackgroundTask:(NSUInteger)identifierID {
    [self.tracingData syncEndBackgroundTaskWithIdentifierID:identifierID];
}

@end
