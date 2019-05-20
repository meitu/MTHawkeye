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


#import "MTHObjcCallTraceHawkeyeAdaptor.h"
#import "MTHCallTrace.h"
#import "MTHCallTraceTimeCostModel.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+ObjcCallTrace.h"
#import "MTHawkeyeUtility.h"

@interface MTHObjcCallTraceHawkeyeAdaptor ()

@end

@implementation MTHObjcCallTraceHawkeyeAdaptor

- (void)dealloc {
    [self unobserveCallTraceSettings];
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observeCallTraceSettings];
    }
    return self;
}

// MARK: - MTHawkeyePlugin

+ (NSString *)pluginID {
    return @"objc-calltrace";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].objcCallTraceOn)
        return;

    [self observeAppEnterBackground];
}

- (void)hawkeyeClientDidStop {
    [self unObserveAppEnterBackground];
}

- (void)receivedFlushStatusCommand {
    if (![MTHCallTrace isRunning])
        return;

    __weak __typeof(self) weakSelf = self;
    static double preWriteDetailTime = 0.f;
    double currentTime = [MTHawkeyeUtility currentTime];
    if (currentTime - preWriteDetailTime > 30.f) {
        preWriteDetailTime = currentTime;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [weakSelf storeCallTraceRecords];
        });
    }
}

// MARK: -
- (void)observeCallTraceSettings {
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(objcCallTraceOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                // wait until next launch.
                [MTHCallTrace setAutoStartAtLaunchEnabled:[newValue boolValue]];
                if ([MTHCallTrace isRunning] && ![newValue boolValue]) {
                    [MTHCallTrace disable];
                }
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(objcCallTraceTimeThresholdInMS))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHCallTrace configureTraceTimeThreshold:[newValue integerValue]];
            }];
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(objcCallTraceDepthLimit))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHCallTrace configureTraceMaxDepth:[newValue integerValue]];
            }];
}

- (void)unobserveCallTraceSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(objcCallTraceOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(objcCallTraceTimeThresholdInMS))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(objcCallTraceDepthLimit))];
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
                                                          [weakSelf storeCallTraceRecords];
                                                      });
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf storeCallTraceRecords];
                                                      });
                                                  }];
}

- (void)storeCallTraceRecords {
    static NSTimeInterval pre = 0.f;
    NSTimeInterval cur = 0.f;
    cur = [MTHawkeyeUtility currentTime];
    if (pre > 0.f && (cur - pre) < 3.f) {
        return;
    }
    pre = cur;

    // 存储没有主动存储的数据
    [self writeCallTraceRecordsToFile];
}

- (void)writeCallTraceRecordsToFile {
    // 增量缓存
    static NSInteger cachedIndex = 0;

    NSArray<MTHCallTraceTimeCostModel *> *records = [MTHCallTrace recordsFromIndex:cachedIndex];
    NSMutableArray *dataToStore = @[].mutableCopy;
    for (NSInteger i = 0; i < records.count; ++i) {
        MTHCallTraceTimeCostModel *record = records[i];
        NSString *key = [NSString stringWithFormat:@"%@", @(cachedIndex + i)];
        NSMutableDictionary *dict = @{}.mutableCopy;
        dict[@"time"] = [NSString stringWithFormat:@"%@", @(record.eventTime)];
        dict[@"class"] = record.className ?: @"";
        dict[@"method"] = record.methodName ?: @"";
        dict[@"cost"] = [NSString stringWithFormat:@"%.2f", record.timeCostInMS];
        dict[@"depth"] = [NSString stringWithFormat:@"%@", @(record.callDepth)];

        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
        if (!jsonData) {
            MTHLogWarn(@"[hawkeye][persistance] persist call trace failed: %@", error.localizedDescription);
        } else {
            NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [dataToStore addObject:@[ key, value ]];
        }
    }

    // each CallTrace record cost 40byte, 1MB of memory can persist 26k records. (enough for debugging)
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        [dataToStore enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            NSString *key = obj[0] ?: @"";
            NSString *value = obj[1] ?: @"";
            [[MTHawkeyeStorage shared] syncStoreValue:value withKey:key inCollection:@"call-trace"];
        }];
    });

    cachedIndex += records.count;
}

@end
