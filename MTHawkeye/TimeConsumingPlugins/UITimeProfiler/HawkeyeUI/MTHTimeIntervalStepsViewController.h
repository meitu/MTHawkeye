//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/20
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHViewControllerAppearRecord;
@class MTHCallTraceTimeCostModel;
@class MTHAppLaunchRecord;


@interface MTHTimeIntervalStepsViewController : UIViewController

/**
 extraRecords element could be MTHCallTraceTimeCostModel or MTHTimeIntervalCustomEventRecord
 */
- (void)setupWithAppLaunchRecord:(MTHAppLaunchRecord *)launchRecord firstVCRecord:(nullable MTHViewControllerAppearRecord *)vcRecord extraRecords:(nullable NSArray *)extraRecords;

/**
 extraRecords element could be MTHCallTraceTimeCostModel or MTHTimeIntervalCustomEventRecord
 */
- (void)setupWithVCRecord:(MTHViewControllerAppearRecord *)vcRecord extraRecords:(nullable NSArray *)extraRecords;

@end

NS_ASSUME_NONNULL_END
