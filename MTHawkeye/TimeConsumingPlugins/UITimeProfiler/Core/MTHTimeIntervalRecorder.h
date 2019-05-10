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


#import <Foundation/Foundation.h>
#import "MTHTimeRecord.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHTimeIntervalRecorderPersistanceDelegate;

typedef BOOL (^MTHViewControllerLifeCycleFilter)(UIViewController *vc);

@interface MTHTimeIntervalRecorder : NSObject

@property (readonly, nullable) MTHAppLaunchRecord *launchRecord;

@property (nonatomic, copy, nullable) MTHViewControllerLifeCycleFilter blacklistFilter;

@property (nonatomic, weak, nullable) id<MTHTimeIntervalRecorderPersistanceDelegate> persistanceDelegate;

+ (instancetype)shared;

- (void)recordViewController:(UIViewController *)vc processInStep:(MTHViewControllerLifeCycleStep)step;
- (void)recordAppLaunchStep:(MTHAppLaunchStep)step;
- (void)recordRunLoopActivities:(NSArray<MTHRunloopActivityRecord *> *)activities;

/**
 You can add your own time event here, the record result will be shown in UITimeProfilerUI.

 the time you call this method will used as the time event happen, call `recordCustomEvent:time:` if need.

 @param event event name
 */
- (void)recordCustomEvent:(NSString *)event;
- (void)recordCustomEvent:(NSString *)event time:(NSTimeInterval)time;
- (void)recordCustomEvent:(NSString *)event extra:(NSString *_Nullable)extra;

/**
 You can add your own time event here, the record result will be shown in UITimeProfilerUI.

 @param event event name
 @param extra extra info for your event
 @param time the time of the event.
 */
- (void)recordCustomEvent:(NSString *)event extra:(NSString *_Nullable)extra time:(NSTimeInterval)time;

@end


@protocol MTHTimeIntervalRecorderPersistanceDelegate <NSObject>

- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistVCRecord:(MTHViewControllerAppearRecord *)record;
- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistLaunchRecord:(MTHAppLaunchRecord *)record;
- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistRunloopActivities:(NSArray<MTHRunloopActivityRecord *> *)runloopActivities;
- (void)timeIntervalRecorder:(MTHTimeIntervalRecorder *)recorder wantPersistCustomEvent:(MTHTimeIntervalCustomEventRecord *)record;

@end

NS_ASSUME_NONNULL_END
