//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 09/11/2017
// Created by: EuanC
//


#import "MTHTimeIntervalRecorder.h"
#import <UIKit/UIKit.h>
#import <sys/time.h>
#import "MTHawkeyeUtility.h"


@interface MTHTimeIntervalRecorder ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, MTHViewControllerAppearRecord *> *recordDict;
@property (nonatomic, strong) NSMutableArray<MTHViewControllerAppearRecord *> *noStoredRecords;

@property (nonatomic, strong, readwrite) MTHAppLaunchRecord *launchRecord;

@end

@implementation MTHTimeIntervalRecorder

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    (self = [super init]);
    if (self) {
        self.launchRecord = [[MTHAppLaunchRecord alloc] init];
        self.launchRecord.appLaunchTime = [MTHawkeyeUtility appLaunchedTime];
    }
    return self;
}

- (void)recordViewController:(UIViewController *)vc processInStep:(MTHViewControllerLifeCycleStep)step {
    if (![vc isKindOfClass:[UIViewController class]] || [vc isKindOfClass:[UINavigationController class]] || [vc isKindOfClass:[UITabBarController class]]) {
        return;
    }

    struct timeval now;
    gettimeofday(&now, NULL);
    NSTimeInterval nowTime = now.tv_sec + now.tv_usec * 1e-6;

    NSString *key = [NSString stringWithFormat:@"%p", vc];

    if (self.blacklistFilter && self.blacklistFilter(vc)) {
        [self.recordDict removeObjectForKey:key];
        return;
    }

    if (self.recordDict == nil) {
        self.recordDict = [NSMutableDictionary dictionary];
        self.noStoredRecords = @[].mutableCopy;
    }

    MTHViewControllerAppearRecord *lifeRecord = self.recordDict[key];
    if (!lifeRecord) {
        lifeRecord = [[MTHViewControllerAppearRecord alloc] init];
        self.recordDict[key] = lifeRecord;
    }

    lifeRecord.objPointer = key;
    lifeRecord.className = NSStringFromClass([vc class]);

    switch (step) {
        case MTHViewControllerLifeCycleStepInitExit:
            lifeRecord.initExitTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepLoadViewEnter:
            lifeRecord.loadViewEnterTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepLoadViewExit:
            lifeRecord.loadViewExitTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewDidLoadEnter:
            lifeRecord.viewDidLoadEnterTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewDidLoadExit:
            lifeRecord.viewDidLoadExitTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewWillAppearEnter:
            lifeRecord.viewWillAppearEnterTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewWillAppearExit:
            lifeRecord.viewWillAppearExitTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewDidAppearEnter:
            lifeRecord.viewDidAppearEnterTime = nowTime;
            break;
        case MTHViewControllerLifeCycleStepViewDidAppearExit: {
            lifeRecord.viewDidAppearExitTime = nowTime;

            if ([self.persistanceDelegate respondsToSelector:@selector(timeIntervalRecorder:wantPersistVCRecord:)]) {
                [self.persistanceDelegate timeIntervalRecorder:self wantPersistVCRecord:lifeRecord];

                if (self.noStoredRecords.count > 0) {
                    for (MTHViewControllerAppearRecord *record in self.noStoredRecords) {
                        [self.persistanceDelegate timeIntervalRecorder:self wantPersistVCRecord:record];
                    }
                    [self.noStoredRecords removeAllObjects];
                }
            } else {
                // if not started, only keep the first 10 records.
                if (self.noStoredRecords.count < 10) {
                    [self.noStoredRecords addObject:lifeRecord];
                }
            }
            self.recordDict[key] = nil;
        } break;
        default:
            break;
    }
}

- (void)recordAppLaunchStep:(MTHAppLaunchStep)step {
    struct timeval now;
    gettimeofday(&now, NULL);
    NSTimeInterval nowTime = now.tv_sec + now.tv_usec * 1e-6;

    switch (step) {
        case MTHAppLaunchStepUnknown:
        case MTHAppLaunchStepAppLaunch:
            break;
        case MTHAppLaunchStepObjcLoadStart:
            self.launchRecord.firstObjcLoadStartTime = nowTime;
            break;
        case MTHAppLaunchStepObjcLoadEnd:
            self.launchRecord.lastObjcLoadEndTime = nowTime;
            break;
        case MTHAppLaunchStepStaticInitializerStart:
            self.launchRecord.staticInitializerStartTime = nowTime;
            break;
        case MTHAppLaunchStepStaticInitializerEnd:
            self.launchRecord.staticInitializerEndTime = nowTime;
            break;
        case MTHAppLaunchStepApplicationInit:
            self.launchRecord.applicationInitTime = nowTime;
            break;
        case MTHAppLaunchStepAppDidLaunchEnter:
            self.launchRecord.appDidLaunchEnterTime = nowTime;
            break;
        case MTHAppLaunchStepAppDidLaunchExit:
            self.launchRecord.appDidLaunchExitTime = nowTime;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.persistanceDelegate timeIntervalRecorder:self wantPersistLaunchRecord:self.launchRecord];
            });
            break;
    }
}

- (void)recordRunLoopActivities:(NSArray<MTHRunloopActivityRecord *> *)runloopActivities {
    if ([self.persistanceDelegate respondsToSelector:@selector(timeIntervalRecorder:wantPersistLaunchRecord:)]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.persistanceDelegate timeIntervalRecorder:self wantPersistRunloopActivities:runloopActivities];
        });
    }
}

- (void)recordCustomEvent:(NSString *)event {
    [self recordCustomEvent:event time:[MTHawkeyeUtility currentTime]];
}

- (void)recordCustomEvent:(NSString *)event time:(NSTimeInterval)time {
    [self recordCustomEvent:event extra:nil time:time];
}

- (void)recordCustomEvent:(NSString *)event extra:(NSString *_Nullable)extra {
    [self recordCustomEvent:event extra:extra time:[MTHawkeyeUtility currentTime]];
}

- (void)recordCustomEvent:(NSString *)event extra:(NSString *_Nullable)extra time:(NSTimeInterval)time {
    if ([self.persistanceDelegate respondsToSelector:@selector(timeIntervalRecorder:wantPersistCustomEvent:)]) {
        MTHTimeIntervalCustomEventRecord *record = [[MTHTimeIntervalCustomEventRecord alloc] init];
        record.timeStamp = time;
        record.event = event;
        record.extra = extra;
        [self.persistanceDelegate timeIntervalRecorder:self wantPersistCustomEvent:record];
    }
}

@end
