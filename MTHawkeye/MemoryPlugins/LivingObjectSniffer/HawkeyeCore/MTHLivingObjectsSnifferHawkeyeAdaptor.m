//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import "MTHLivingObjectsSnifferHawkeyeAdaptor.h"
#import "MTHLivingObjectSniffService.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+LivingObjectsSniffer.h"
#import "MTHawkeyeUtility.h"


@interface MTHLivingObjectsSnifferHawkeyeAdaptor () <MTHLivingObjectSnifferDelegate>

@end


@implementation MTHLivingObjectsSnifferHawkeyeAdaptor

- (void)dealloc {
}

- (instancetype)init {
    if ((self = [super init])) {
    }
    return self;
}

- (void)unobserveSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(livingObjectsSnifferOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(livingObjectSnifferTaskDelayInSeconds))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(livingObjectsSnifferContainerSniffEnabled))];
}

- (void)observeSettings {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(livingObjectsSnifferOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue]) {
                    [weakSelf hawkeyeClientDidStart];
                } else {
                    [weakSelf hawkeyeClientDidStop];
                }
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(livingObjectSnifferTaskDelayInSeconds))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHLivingObjectSniffService shared].delaySniffInSeconds = [newValue floatValue];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(livingObjectsSnifferContainerSniffEnabled))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                mthawkeye_livingObjectsSnifferNSFoundationContainerEnabled = [newValue boolValue];
            }];
}

+ (NSString *)pluginID {
    return @"living-oc-objects-sniffer";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].livingObjectsSnifferOn)
        return;

    if ([MTHLivingObjectSniffService shared].isRunning)
        return;

    [self observeAppEnterBackground];
    [self observeSettings];

    [[MTHLivingObjectSniffService shared].sniffer addDelegate:self];
    [[MTHLivingObjectSniffService shared] start];

    mthawkeye_livingObjectsSnifferNSFoundationContainerEnabled = [MTHawkeyeUserDefaults shared].livingObjectsSnifferContainerSniffEnabled;

    MTHLogInfo(@"living object sniffer start");
}

- (void)hawkeyeClientDidStop {
    if (![MTHLivingObjectSniffService shared].isRunning)
        return;

    [self unobserveSettings];
    [self unObserveAppEnterBackground];
    [[MTHLivingObjectSniffService shared].sniffer removeDelegate:self];
    [[MTHLivingObjectSniffService shared] stop];

    MTHLogInfo(@"living object sniffer stop");
}

- (void)receivedFlushStatusCommand {
    if (![MTHLivingObjectSniffService shared].isRunning)
        return;

    __weak __typeof(self) weakSelf = self;

    static double preWriteDetailTime = 0.f;
    double currentTime = [MTHawkeyeUtility currentTime];
    if (currentTime - preWriteDetailTime > 15.f) {
        preWriteDetailTime = currentTime;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [weakSelf writeAliveObjCObjectsRecordsToFile];
        });
    }
}

// MARK: - MTHLivingObjectSnifferDelegate

- (void)livingObjectSniffer:(MTHLivingObjectSniffer *)sniffer didSniffOutResult:(MTHLivingObjectShadowPackageInspectResult *)result {
    [self recordShadowTriggerInfo:result.trigger];
}

// MARK: - storage

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
                                                          [weakSelf writeAliveObjCObjectsRecordsToFile];
                                                      });
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [weakSelf writeAliveObjCObjectsRecordsToFile];
                                                      });
                                                  }];
}

- (void)writeAliveObjCObjectsRecordsToFile {
    static NSTimeInterval pre = 0.f;
    NSTimeInterval cur = 0.f;
    cur = [MTHawkeyeUtility currentTime];
    if (pre > 0.f && (cur - pre) < 3.f) {
        return;
    }
    pre = cur;

    [self writeAliveObjcObjectsToFile];
}

- (void)writeAliveObjcObjectsToFile {
    NSArray<MTHLivingObjectGroupInClass *> *instsGroups = [MTHLivingObjectSniffService shared].sniffer.livingObjectGroupsInClass;

    // 简单去除重复的存储操作，特殊场景下可能有误伤
    static NSInteger cachedAliveClassCount = 0;
    if (cachedAliveClassCount == instsGroups.count) {
        static NSInteger cachedAliveInstanceCount = 0;

        NSInteger curAliveInstanceCount = 0;
        for (MTHLivingObjectGroupInClass *instsGroup in instsGroups) {
            curAliveInstanceCount += instsGroup.aliveInstanceCount;
        }

        if (cachedAliveInstanceCount == curAliveInstanceCount) {
            return;
        }
        cachedAliveInstanceCount = curAliveInstanceCount;
    }
    cachedAliveClassCount = instsGroups.count;

    NSString *beginDate = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility appLaunchedTime])];
    NSString *endDate = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    NSMutableDictionary *valueDict = @{}.mutableCopy;
    valueDict[@"begin_date"] = beginDate;
    valueDict[@"end_date"] = endDate;

    NSMutableArray *aliveInstsJson = @[].mutableCopy;
    for (MTHLivingObjectGroupInClass *instsGroup in instsGroups) {
        NSMutableDictionary *itemDict = @{}.mutableCopy;
        itemDict[@"class_name"] = instsGroup.className ?: @"";
        itemDict[@"alive_instance_count"] = [NSString stringWithFormat:@"%@", @(instsGroup.aliveInstanceCount)];

        NSMutableArray *instsListGroup = @[].mutableCopy;
        for (MTHLivingObjectInfo *insts in instsGroup.aliveInstances) {
            [instsListGroup addObject:@{
                @"pre_holder_name" : insts.preHolderName ?: @"",
                @"instance" : [NSString stringWithFormat:@"%p", insts.instance],
                @"time" : [NSString stringWithFormat:@"%@", @(insts.recordTime)],
                @"not_owner" : @(insts.theHodlerIsNotOwner),
            }];
        }
        itemDict[@"instances"] = instsListGroup.copy;

        // 自动化有 Cell 泄漏的问题，因此记录标记位，分析时可以根据标记位忽略该泄漏
        BOOL isACell = [instsGroup.aliveInstances.firstObject.instance isKindOfClass:[UITableViewCell class]]
                       || [instsGroup.aliveInstances.firstObject.instance isKindOfClass:[UICollectionViewCell class]];

        itemDict[@"is_a_cell"] = @(isACell);

        [aliveInstsJson addObject:itemDict.copy];
    }

    valueDict[@"alive_instances_collect"] = aliveInstsJson.copy;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:valueDict.copy options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn(@"store vc will dealloc failed: %@", error.localizedDescription);
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"alive-objc-obj.mtlog"];
        dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
            [jsonData writeToFile:path options:NSDataWritingAtomic error:nil];
        });
    }
}

- (void)recordShadowTriggerInfo:(MTHLivingObjectShadowTrigger *)trigger {
    static NSInteger livingObjectShadowTriggerIdx = 0;
    NSString *key = [NSString stringWithFormat:@"%@", @(livingObjectShadowTriggerIdx++)];

    NSDictionary *dict = [trigger inDictionary];
    if (!dict)
        return;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn(@"store vc will dealloc failed: %@", error.localizedDescription);
    } else {
        NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[MTHawkeyeStorage shared] asyncStoreValue:value
                                           withKey:key
                                      inCollection:@"obj-shadow-trigger"];
    }
}

@end
