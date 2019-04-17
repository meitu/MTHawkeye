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


#import <Foundation/Foundation.h>
#import "MTHawkeyePlugin.h"

#define kMTHDirectoryWatcherWarningNotification @"kMTHDirectoryWatcherWarningNotification"
#define kMTHDirectoryWatcherTriggerLimitNotification @"kMTHDirectoryWatcherTriggerLimitNotification"
NS_ASSUME_NONNULL_BEGIN

@interface MTHDirectoryWatcherHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

@end

NS_ASSUME_NONNULL_END
