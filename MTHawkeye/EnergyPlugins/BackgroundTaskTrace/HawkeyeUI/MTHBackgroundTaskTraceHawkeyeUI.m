//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/10/18
// Created by: David.Dai
//

#import "MTHBackgroundTaskTraceHawkeyeUI.h"
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import "MTHawkeyeUserDefaults+BackgroundTaskTrace.h"

@implementation MTHBackgroundTaskTraceHawkeyeUI

+ (nonnull NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupEnergy;
}

+ (nonnull MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"BackgroundTask Trace";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].backgroundTaskTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].backgroundTaskTraceOn) {
            [MTHawkeyeUserDefaults shared].backgroundTaskTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

@end
