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


#import <Foundation/Foundation.h>
#import <MTHawkeye/MTHawkeyePlugin.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kMTHawkeyeNotificationNameFirstVCDidAppeared;
extern BOOL mthawkeye_VCTraceIgnoreSystemVC; // default yes.

@class MTHViewControllerAppearRecord;
@class MTHTimeIntervalCustomEventRecord;

@interface MTHUITimeProfilerHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

+ (NSArray<MTHViewControllerAppearRecord *> *)readViewControllerAppearedRecords;
+ (NSArray<MTHTimeIntervalCustomEventRecord *> *)readCustomEventRecords;

@end

NS_ASSUME_NONNULL_END
