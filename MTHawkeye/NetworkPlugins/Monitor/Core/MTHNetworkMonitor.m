//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import "MTHNetworkMonitor.h"
#import "MTHNetworkObserver.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkStat.h"
#import "MTHNetworkTransaction.h"

@interface MTHNetworkMonitor () <MTHNetworkRecorderDelegate>

@end

@implementation MTHNetworkMonitor

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)dealloc {
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)start {
    [MTHNetworkObserver setEnabled:YES];

    [[MTHNetworkRecorder defaultRecorder] addDelegate:self];
}

- (void)stop {
    [MTHNetworkObserver setEnabled:NO];

    [[MTHNetworkRecorder defaultRecorder] removeDelegate:self];
}

- (BOOL)isRunning {
    return [MTHNetworkObserver isEnabled];
}

// MARK: - Network
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (void)recorderWantCacheTransactionAsUpdated:(MTHNetworkTransaction *)transaction currentState:(MTHNetworkTransactionState)state {
    if (transaction.transactionState == MTHNetworkTransactionStateFinished) {
        if (transaction.useURLSessionTaskMetrics) {
            // 过滤缓存情况
            NSURLSessionTaskTransactionMetrics *metrics = [transaction.taskMetrics.transactionMetrics lastObject];
            if (metrics.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache) {
                return;
            } else {
                int64_t bytes = transaction.receivedDataLength;

                // 现有 api 无法准确获取到开始下发的时间，只能采用估算方式
                // (response.start - request.end) * 2 / 3 ~ response.end
                NSTimeInterval rspStart2RspEnd = [metrics.responseEndDate timeIntervalSinceDate:metrics.responseStartDate];
                NSTimeInterval reqEnd2RspStart = [metrics.responseStartDate timeIntervalSinceDate:metrics.requestEndDate];
                NSTimeInterval duration = reqEnd2RspStart * 2.f / 3.f + rspStart2RspEnd;
                [[MTHNetworkStat shared] addBandwidthWithBytes:bytes duration:duration * 1000];
            }
        }

        // 非 URLSessionTaskMetrics 统计，统计误差较大，暂不计入
    }
}

#pragma clang diagnostic pop

@end
