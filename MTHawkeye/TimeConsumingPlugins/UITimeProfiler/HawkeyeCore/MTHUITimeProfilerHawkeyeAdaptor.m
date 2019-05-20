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


#import "MTHUITimeProfilerHawkeyeAdaptor.h"
#import "MTHAppLaunchStepTracer.h"
#import "MTHTimeIntervalRecorder.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+UITimeProfiler.h"
#import "UIViewController+MTHProfile.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeHooking.h>


NSNotificationName kMTHawkeyeNotificationNameFirstVCDidAppeared = @"com.meitu.hawkeye.vc.first_appeared";

BOOL mthawkeye_VCTraceIgnoreSystemVC = YES;

@interface MTHUITimeProfilerHawkeyeAdaptor () <MTHTimeIntervalRecorderPersistanceDelegate>

@end

@implementation MTHUITimeProfilerHawkeyeAdaptor

+ (void)load {
    if (![MTHawkeyeUserDefaults shared].hawkeyeOn)
        return;

    [MTHAppLaunchStepTracer traceSteps];

    if ([MTHawkeyeUserDefaults shared].vcLifeTraceOn) {
        [UIViewController startVCProfile];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        __weak __typeof(self) weakSelf = self;
        [[MTHawkeyeUserDefaults shared]
            mth_addObserver:self
                     forKey:NSStringFromSelector(@selector(vcLifeTraceOn))
                withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                    if ([newValue boolValue]) {
                        [weakSelf hawkeyeClientDidStart];
                    } else {
                        [weakSelf hawkeyeClientDidStop];
                    }
                }];
    }
    return self;
}

// MARK: - MTHawkeyePlugin

+ (NSString *)pluginID {
    return @"ui-time-profiler";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].vcLifeTraceOn)
        return;

    // start if needed.
    [UIViewController startVCProfile];
    [MTHTimeIntervalRecorder shared].blacklistFilter = ^BOOL(UIViewController *vc) {
        if (mthawkeye_VCTraceIgnoreSystemVC && mtha_addr_is_in_sys_libraries((vm_address_t)vc.class)) {
            return YES;
        }
        if ([vc isViewLoaded] && [vc.view.window isKindOfClass:NSClassFromString(@"MTHFloatingMonitorWindow")]) {
            return YES;
        } else {
            return NO;
        }
    };
    [MTHTimeIntervalRecorder shared].persistanceDelegate = self;

    MTHLogInfo(@"ui time profiler start");
}

- (void)hawkeyeClientDidStop {
    [MTHTimeIntervalRecorder shared].persistanceDelegate = nil;

    MTHLogInfo(@"ui time profiler stop");
}

// MARK: - storage

+ (NSArray<MTHViewControllerAppearRecord *> *)readViewControllerAppearedRecords {
    NSArray<NSString *> *recordStrings;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"view-ctrl" keys:nil values:&recordStrings];

    if (!recordStrings.count) {
        return nil;
    }

    NSMutableArray<MTHViewControllerAppearRecord *> *records = [NSMutableArray arrayWithCapacity:recordStrings.count];
    [recordStrings enumerateObjectsUsingBlock:^(NSString *_Nonnull aRecordLine, NSUInteger idx, BOOL *_Nonnull stop) {
        NSDictionary *recordDict = [NSJSONSerialization JSONObjectWithData:[aRecordLine dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if (!recordDict)
            return;

        MTHViewControllerAppearRecord *aRecord = [[MTHViewControllerAppearRecord alloc] init];
        aRecord.className = recordDict[@"name"] ?: @"";

        aRecord.initExitTime = [recordDict[@"initExit"] doubleValue];
        aRecord.loadViewEnterTime = [recordDict[@"loadViewEnter"] doubleValue];
        aRecord.loadViewExitTime = [recordDict[@"loadViewExit"] doubleValue];
        aRecord.viewDidLoadEnterTime = [recordDict[@"didLoadEnter"] doubleValue];
        aRecord.viewDidLoadExitTime = [recordDict[@"didLoadExit"] doubleValue];
        aRecord.viewWillAppearEnterTime = [recordDict[@"willAppearEnter"] doubleValue];
        aRecord.viewWillAppearExitTime = [recordDict[@"willAppearExit"] doubleValue];
        aRecord.viewDidAppearEnterTime = [recordDict[@"didAppearEnter"] doubleValue];
        aRecord.viewDidAppearExitTime = [recordDict[@"didAppearExit"] doubleValue];

        [records addObject:aRecord];
    }];
    return [records copy];
}

+ (NSArray<MTHTimeIntervalCustomEventRecord *> *)readCustomEventRecords {
    NSArray<NSString *> *recordsString;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"custom-time-event" keys:nil values:&recordsString];
    if (recordsString.count == 0)
        return nil;

    NSMutableArray<MTHTimeIntervalCustomEventRecord *> *records = [NSMutableArray arrayWithCapacity:recordsString.count];
    [recordsString enumerateObjectsUsingBlock:^(NSString *_Nonnull aRecordLine, NSUInteger idx, BOOL *_Nonnull stop) {
        NSDictionary *recordDict = [NSJSONSerialization JSONObjectWithData:[aRecordLine dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if (!recordDict)
            return;

        MTHTimeIntervalCustomEventRecord *record = [[MTHTimeIntervalCustomEventRecord alloc] init];
        record.timeStamp = [recordDict[@"time"] doubleValue];
        record.event = recordDict[@"event"] ?: @"";
        record.extra = recordDict[@"extra"] ?: @"";
        [records addObject:record];
    }];
    return [records copy];
}

// MARK:  MTHTimeIntervalRecorderPersistanceDelegate
- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistVCRecord:(MTHViewControllerAppearRecord *)record {
    if (record.viewDidAppearExitTime <= 0.f)
        return;

    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        static NSInteger index = 0;

        NSString *key = [NSString stringWithFormat:@"%@", @(index++)];
        NSMutableDictionary *dict = @{}.mutableCopy;
        dict[@"name"] = record.className ?: @"";
        dict[@"initExit"] = @(record.initExitTime);
        dict[@"loadViewEnter"] = @(record.loadViewEnterTime);
        dict[@"loadViewExit"] = @(record.loadViewExitTime);
        dict[@"didLoadEnter"] = @(record.viewDidLoadEnterTime);
        dict[@"didLoadExit"] = @(record.viewDidLoadExitTime);
        dict[@"willAppearEnter"] = @(record.viewWillAppearEnterTime);
        dict[@"willAppearExit"] = @(record.viewWillAppearExitTime);
        dict[@"didAppearEnter"] = @(record.viewDidAppearEnterTime);
        dict[@"didAppearExit"] = @(record.viewDidAppearExitTime);

        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
        if (!jsonData) {
            MTHLogWarn(@"[hawkeye][persistance] persist vc record failed: %@", error.localizedDescription);
        } else {
            NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [[MTHawkeyeStorage shared] syncStoreValue:value withKey:key inCollection:@"view-ctrl"];

            if (index == 1) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMTHawkeyeNotificationNameFirstVCDidAppeared object:nil userInfo:@{@"vc" : record ?: @""}];
                });
            }
        }
    });
}

- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistLaunchRecord:(MTHAppLaunchRecord *)record {
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        NSMutableDictionary *dict = @{}.mutableCopy;
        dict[@"appLaunchTime"] = @(record.appLaunchTime);
        dict[@"firstObjcLoadStartTime"] = @(record.firstObjcLoadStartTime);
        dict[@"lastObjcLoadEndTime"] = @(record.lastObjcLoadEndTime);
        dict[@"staticInitializerStartTime"] = @(record.staticInitializerStartTime);
        dict[@"staticInitializerEndTime"] = @(record.staticInitializerEndTime);
        dict[@"applicationInitTime"] = @(record.applicationInitTime);
        dict[@"appDidLaunchEnterTime"] = @(record.appDidLaunchEnterTime);
        dict[@"appDidLaunchExitTime"] = @(record.appDidLaunchExitTime);

        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
        if (!jsonData) {
            MTHLogWarn(@"[hawkeye][persistance] persist app launch record failed: %@", error.localizedDescription);
        } else {
            NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *key = @"0";
            [[MTHawkeyeStorage shared] syncStoreValue:value withKey:key inCollection:@"app-launch"];
        }
    });
}

- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistRunloopActivities:(NSArray<MTHRunloopActivityRecord *> *)runloopActivities {
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        for (MTHRunloopActivityRecord *activityRecord in runloopActivities) {
            NSString *timeStampString = [NSString stringWithFormat:@"%lf", activityRecord.timeStamp];
            NSString *activityString = [NSString stringWithFormat:@"%lu", activityRecord.activity];
            [[MTHawkeyeStorage shared] syncStoreValue:activityString withKey:timeStampString inCollection:@"head-runloop"];
        }
    });
}

- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistCustomEvent:(MTHTimeIntervalCustomEventRecord *)record {
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        NSMutableDictionary *dict = @{}.mutableCopy;
        NSString *timeStampString = [NSString stringWithFormat:@"%lf", record.timeStamp];
        dict[@"time"] = @(record.timeStamp);
        if (record.event.length > 0)
            dict[@"event"] = record.event;

        if (record.extra.length > 0)
            dict[@"extra"] = record.extra;

        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
        if (!jsonData) {
            MTHLogWarn(@"[hawkeye][persistance] persist app launch record failed: %@", error.localizedDescription);
        } else {
            NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [[MTHawkeyeStorage shared] syncStoreValue:value withKey:timeStampString inCollection:@"custom-time-event"];
        }
    });
}

@end
