//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/20
// Created by: EuanC
//


#import "MTHOpenGLTraceHawkeyeAdaptor.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+OpenGLTrace.h"
#import "MTHawkeyeUtility.h"

#import <MTGLDebug/MTGLDebug.h>


@interface MTHOpenGLTraceHawkeyeAdaptor () <MTGLDebugErrorMessageDelegate>

@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, strong) NSHashTable<id<MTHOpenGLTraceDelegate>> *delegates;

@end

static size_t _openGLESResourceMemorySize;

@implementation MTHOpenGLTraceHawkeyeAdaptor

- (void)dealloc {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(openGLTraceAnalysisOn))];

    [MTGLDebug setDelegate:nil];
}

- (instancetype)init {
    if ((self = [super init])) {
        [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                                 forKey:NSStringFromSelector(@selector(openGLTraceAnalysisOn))
                                            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                                MTGLDebug.enableOnlyStatisticalGLObject = ![newValue boolValue];
                                            }];
    }
    return self;
}

- (NSArray *)alivingMemoryGLObjects {
    return [[[MTGLDebug sortedDebugObjectsByMemory] reverseObjectEnumerator] allObjects];
}

// MARK: - MTHawkeyePlugin

+ (NSString *)pluginID {
    return @"gl-tracer";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].openGLTraceOn)
        return;

    if (self.isRunning)
        return;
    self.isRunning = YES;

    [MTGLDebug setDelegate:self];
    [MTGLDebug registerMTGLDebugHook];
    MTGLDebug.enableOnlyStatisticalGLObject = ![MTHawkeyeUserDefaults shared].openGLTraceAnalysisOn;
    [self observeAppEnterBackground];

    MTHLogInfo(@"opengl tracer start");
}

- (void)hawkeyeClientDidStop {
    if (!self.isRunning)
        return;

    self.isRunning = NO;

    [self unObserveAppEnterBackground];

    MTHLogInfo(@"opengl tracer stop");
}

- (void)receivedFlushStatusCommand {
    if (!self.isRunning)
        return;

    static NSTimeInterval preFlushTime = 0;
    NSTimeInterval curTime = [MTHawkeyeUtility currentTime];
    if (curTime - preFlushTime < 1.f) {
        return;
    }
    preFlushTime = curTime;

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        size_t glMemoryUsedInByte = [MTGLDebug fetchOpenGLESResourceMemorySize];
        MTHOpenGLTraceHawkeyeAdaptor.openGLESResourceMemorySize = glMemoryUsedInByte;
        static size_t preGLMemeory = 0;
        if (preGLMemeory == glMemoryUsedInByte)
            return;

        preGLMemeory = glMemoryUsedInByte;

        CGFloat glMemoryInMB = glMemoryUsedInByte / 1024.f / 1024.f;
        NSString *time = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility currentTime])];
        NSString *glMemoryStore = [NSString stringWithFormat:@"%.3f", glMemoryInMB];
        [[MTHawkeyeStorage shared] asyncStoreValue:glMemoryStore
                                           withKey:time
                                      inCollection:@"gl-mem"];

        @synchronized(self.delegates) {
            for (id<MTHOpenGLTraceDelegate> delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(glTracer:didUpdateMemoryUsed:)]) {
                    [delegate glTracer:self didUpdateMemoryUsed:glMemoryUsedInByte];
                }
            }
        }

        BOOL needFlushLivingObjs = NO;
        BOOL needUpdateLivingObjsStore = NO;

        static double preWriteDetailTime = 0.f;
        double currentTime = [MTHawkeyeUtility currentTime];
        if (currentTime - preWriteDetailTime > 15.f) {
            preWriteDetailTime = currentTime;
            needFlushLivingObjs = YES;
            needUpdateLivingObjsStore = YES;
        }

        @synchronized(self.delegates) {
            for (id<MTHOpenGLTraceDelegate> delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(glTracerDidUpdateAliveGLObjects:)]) {
                    needFlushLivingObjs = YES;
                    break;
                }
            }
        }

        if (needFlushLivingObjs) {
            for (id<MTHOpenGLTraceDelegate> delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(glTracerDidUpdateAliveGLObjects:)]) {
                    [delegate glTracerDidUpdateAliveGLObjects:self];
                }
            }

            if (needUpdateLivingObjsStore) {
                [weakSelf writeOpenGLRecordsToFiles];
            }
        }
    });
}

// MARK: -
- (void)unObserveAppEnterBackground {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (void)observeAppEnterBackground {
    __weak __typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf writeOpenGLRecordsToFiles];
                                                      });
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf writeOpenGLRecordsToFiles];
                                                      });
                                                  }];
}

- (void)writeOpenGLRecordsToFiles {
    static NSTimeInterval pre = 0.f;
    NSTimeInterval cur = 0.f;
    cur = [MTHawkeyeUtility currentTime];
    if (pre > 0.f && (cur - pre) < 3.f) {
        return;
    }
    pre = cur;

    [self writeAliveGLMemoryInstancesToFile];
}

- (void)writeAliveGLMemoryInstancesToFile {
    // 简单去除重复的存储逻辑，可能误伤
    static NSInteger cachedGLMemoryUsage = 0.f;
    NSInteger curGLMemoryUsage = [MTGLDebug fetchOpenGLESResourceMemorySize];
    if (curGLMemoryUsage == cachedGLMemoryUsage) {
        return;
    }
    cachedGLMemoryUsage = curGLMemoryUsage;

    NSString *beginDate = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility appLaunchedTime])];
    NSString *endDate = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    NSMutableDictionary *valueDict = @{}.mutableCopy;
    valueDict[@"begin_date"] = beginDate;
    valueDict[@"end_date"] = endDate;

    NSMutableArray *aliveInstsJson = @[].mutableCopy;
    NSArray<MTGLDebugObject *> *objs = [MTGLDebug sortedDebugObjectsByMemory];
    for (MTGLDebugObject *obj in objs) {
        NSMutableDictionary *itemDict = @{}.mutableCopy;
        itemDict[@"target"] = obj.targetString;
        itemDict[@"time"] = [NSString stringWithFormat:@"%@", @(obj.timestampInDouble)];
        itemDict[@"size"] = [NSString stringWithFormat:@"%@", @(obj.memorySize)];

        if ([obj isKindOfClass:[MTGLDebugTextureObject class]]) {
            itemDict[@"width"] = [NSString stringWithFormat:@"%@", @(((MTGLDebugTextureObject *)obj).width)];
            itemDict[@"height"] = [NSString stringWithFormat:@"%@", @(((MTGLDebugTextureObject *)obj).height)];
        }
        [aliveInstsJson addObject:itemDict.copy];
    }
    valueDict[@"alive_gl_resources_collect"] = aliveInstsJson.copy;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:valueDict.copy options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn(@"[hawkeye][persistance] persist alive-gl-object failed: %@", error.localizedDescription);
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"alive-gl-obj.mtlog"];
        dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
            [jsonData writeToFile:path options:NSDataWritingAtomic error:nil];
        });
    }
}

// MARK: - delegate

- (void)addDelegate:(id<MTHOpenGLTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<MTHOpenGLTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates removeObject:delegate];
    }
}

// MARK: -

+ (size_t)openGLESResourceMemorySize {
    return _openGLESResourceMemorySize;
}

+ (void)setOpenGLESResourceMemorySize:(NSInteger)openGLESResourceMemorySize {
    _openGLESResourceMemorySize = openGLESResourceMemorySize;
}

- (void)glDebugErrorMessageHandler:(NSString *)errorMessage errorType:(MTGLDebugErrorType)type {

    if ([MTHawkeyeUserDefaults shared].openGLTraceRaiseExceptionOn) {
        [NSException exceptionWithName:@"GL Error" reason:errorMessage userInfo:nil];
    } else {
        for (id<MTHOpenGLTraceDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(glTracer:didReceivedErrorMsg:)]) {
                [delegate glTracer:self didReceivedErrorMsg:errorMessage];
            }
        }
    }
}

@end
