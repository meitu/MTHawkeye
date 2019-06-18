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


#import "MTHANRHawkeyeUI.h"
#import "MTHANRRecordsViewController.h"
#import "MTHANRTrace.h"
#import "MTHawkeyeUserDefaults+ANRMonitor.h"

#import <MTHawkeye/MTHMonitorViewCell.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/MTHawkeyeUIClient.h>


@interface MTHANRHawkeyeUI () <MTHANRTraceDelegate>

@end


@implementation MTHANRHawkeyeUI

- (void)dealloc {
    [[MTHANRTrace shared] removeDelegate:self];
}

- (instancetype)init {
    if ((self = [super init])) {
        [[MTHANRTrace shared] addDelegate:self];
    }
    return self;
}

// MARK: - MTHANRTraceDelegate
- (void)mth_anrMonitor:(MTHANRTrace *)anrMonitor didDetectANR:(MTHANRRecord *)anrRecord {
    NSDictionary *params = @{
        kMTHFloatingWidgetRaiseWarningParamsPanelIDKey : [self mainPanelIdentity],
        kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey : @(3.f)
    };
    [[MTHawkeyeUIClient shared] raiseWarningOnFloatingWidget:@"fps/gpuimage-fps" withParams:params];
}

// MARK: - MTHawkeyeMainPanelPlugin
- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupTimeConsuming;
}

- (NSString *)switchingOptionTitle {
    return @"ANR Records";
}

- (NSString *)mainPanelIdentity {
    return @"anr-records";
}

- (UIViewController *)mainPanelViewController {
    MTHANRRecordsViewController *vc = [[MTHANRRecordsViewController alloc] initWithANRMonitor:[MTHANRTrace shared]];
    return vc;
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupTimeConsuming;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"ANR Trace";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [self anrSettingsSection],
    ];
    return cell;
}

+ (MTHawkeyeSettingSectionEntity *)anrSettingsSection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"anr-trace";
    primary.headerText = @"ANR Trace";
    primary.footerText = @"";
    primary.cells = @[
        [self anrTraceSwitcherCell],
        [self anrThresholdEditorCell]
    ];
    return primary;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)anrTraceSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace ANR";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].anrTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].anrTraceOn) {
            [MTHawkeyeUserDefaults shared].anrTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)anrThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"ANR Threshold";
    editor.inputTips = @"";
    editor.editorKeyboardType = UIKeyboardTypeNumbersAndPunctuation;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].anrThresholdInSeconds;
        NSString *str = [NSString stringWithFormat:@"%.2f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].anrThresholdInSeconds) > DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].anrThresholdInSeconds = value;
        return YES;
    };
    return editor;
}

@end
