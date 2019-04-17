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


#import <Foundation/Foundation.h>
#import "MTHawkeyeUIPlugin.h"

NS_ASSUME_NONNULL_BEGIN

/*
 Raise warning by flash label on the Hawkeye floating window
 only if the number of unexpected living instances of a View class exceeds this value.

 Default 20.
 */
extern NSInteger gHawkeyeWarningUnexpectedLivingCellViewCount;

/*
 Raise warning by flash label on the Hawkeye floating window
 only if the number of unexpected living instances of a View class exceeds this value.

 Default count is 5.
 */
extern NSInteger gHawkeyeWarningUnexpectedLivingViewCount;

/*
 The flush duration on the Hawkeye floating window when the warning is triggered.
 */
extern CGFloat gHawkeyeWarningUnexpectedLivingObjectFlashDuration;

/*
 The duration of the toast when warning unexpected living View Controller
 */
extern CGFloat gHawkeyeWarningUnexpectedLivingVCObjectToastDuration;

@class MTHawkeyeSettingSectionEntity;

@interface MTHLivingObjectsSnifferHawkeyeUI : NSObject <MTHawkeyeMainPanelPlugin, MTHawkeyeSettingUIPlugin>

@end

NS_ASSUME_NONNULL_END
