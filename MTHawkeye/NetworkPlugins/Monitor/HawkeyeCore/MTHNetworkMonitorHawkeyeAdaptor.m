//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHNetworkMonitorHawkeyeAdaptor.h"
#import "MTHNetworkMonitor.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkRecordsStorage.h"
#import "MTHNetworkTransaction.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeUserDefaults+NetworkMonitor.h"

@interface MTHNetworkMonitorHawkeyeAdaptor () <MTHNetworkRecorderDelegate>

@end

@implementation MTHNetworkMonitorHawkeyeAdaptor

- (void)dealloc {
    [self unobserveNetworkSettings];
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observeNetworkSettings];
    }
    return self;
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"network-monitor";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].networkMonitorOn)
        return;

    //此处delegate的设置时机会导致最起始的部分网络请求记录记录失效
    [[MTHNetworkRecorder defaultRecorder] addDelegate:self];
    [[MTHNetworkMonitor shared] start];

    MTHLogInfo(@"network tracing start");
}

- (void)hawkeyeClientDidStop {
    if (![[MTHNetworkMonitor shared] isRunning])
        return;

    [[MTHNetworkRecorder defaultRecorder] removeDelegate:self];
    [[MTHNetworkMonitor shared] stop];

    MTHLogInfo(@"network tracing stop");
}

// MARK: - User defaults
- (void)observeNetworkSettings {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(networkMonitorOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf hawkeyeClientDidStart];
                else
                    [weakSelf hawkeyeClientDidStop];
            }];
}

- (void)unobserveNetworkSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(networkMonitorOn))];
}

// MARK: - Storage
- (void)recorderWantCacheNewTransaction:(MTHNetworkTransaction *)transaction {
    // do nothing.
}

- (void)recorderWantCacheTransactionAsUpdated:(MTHNetworkTransaction *)transaction currentState:(MTHNetworkTransactionState)state {
    // 获取缓存的状态，而不是最新的 transaction.transactionState 状态（在通知过程中可能已变更），避免重入
    if (state != MTHNetworkTransactionStateFailed && state != MTHNetworkTransactionStateFinished)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        if (![MTHawkeyeUserDefaults shared].responseBodyCacheOn) {
            transaction.responseBody = nil;
        }

        [[MTHNetworkRecordsStorage shared] storeNetworkTransaction:transaction];

        // simply limit the cache
        static NSTimeInterval preTrimTime = 0;
        static NSInteger i = 0;
        NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
        if (i++ % 20 == 0 || currentTime - preTrimTime > 20) {
            [MTHNetworkRecordsStorage trimCurrentSessionLargeRecordsToCost:[MTHawkeyeUserDefaults shared].networkCacheLimitInMB];
            preTrimTime = currentTime;
        }
    });
}

@end
