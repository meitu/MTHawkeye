//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/09/2017
// Created by: EuanC
//


#import "MTHANRTrace.h"
#import "MTHANRObserver.h"
#import "MTHANRRecord.h"

@interface MTHANRTrace ()

@property (nonatomic, strong) NSHashTable<id<MTHANRTraceDelegate>> *delegates;
@property (nonatomic, strong) MTHANRObserver *observer;

@end


@implementation MTHANRTrace

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _thresholdInSeconds = 0.4;
    }
    return self;
}

- (void)start {
    if (!self.observer.isRunning) {
        __weak typeof(self) weakSelf = self;
        self.observer = [[MTHANRObserver alloc] initWithObserveResultHandler:^(MTHANRObserver *anrMonitor, MTHANRRecordRaw *recordRaw) {
            if (!recordRaw)
                return;

            [weakSelf.delegates.allObjects enumerateObjectsUsingBlock:^(id<MTHANRTraceDelegate> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if ([obj respondsToSelector:@selector(mth_anrMonitor:didDetectANR:)]) {
                    [obj mth_anrMonitor:weakSelf didDetectANR:recordRaw];
                }
            }];
        }];

        self.observer.shouldCaptureBackTrace = self.shouldCaptureBackTrace;
        [self.observer startWithThresholdInSeconds:self.thresholdInSeconds];
    }
}

- (void)stop {
    if (self.observer.isRunning) {
        [self.observer stop];
    }
}

- (BOOL)isRunning {
    return self.observer.isRunning;
}

- (void)setThresholdInSeconds:(CGFloat)thresholdInSeconds {
    if (fabs(_thresholdInSeconds - thresholdInSeconds) > DBL_EPSILON) {
        _thresholdInSeconds = thresholdInSeconds;

        if (self.observer.isRunning) {
            [self stop];
            [self start];
        }
    }
}

- (void)addDelegate:(id<MTHANRTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<MTHANRTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates removeObject:delegate];
    }
}

// MAKR: getter
- (NSHashTable<id<MTHANRTraceDelegate>> *)delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSHashTableWeakMemory];
    }
    return _delegates;
}

@end
