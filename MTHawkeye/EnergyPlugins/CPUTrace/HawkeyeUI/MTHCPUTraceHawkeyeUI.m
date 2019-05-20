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


#import "MTHCPUTraceHawkeyeUI.h"
#import "MTHCPURecordsViewController.h"
#import "MTHawkeyeUserDefaults+CPUTrace.h"

#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>


@implementation MTHCPUTraceHawkeyeUI

// MARK: - MTHawkeyeMainPanelPlugin
- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupEnergy;
}

- (NSString *)switchingOptionTitle {
    return @"CPU Trace";
}

- (NSString *)mainPanelIdentity {
    return @"cpu-trace";
}


- (UIViewController *)mainPanelViewController {
    MTHCPURecordsViewController *vc = [MTHCPURecordsViewController new];
    return vc;
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupEnergy;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"CPU Trace";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [self cpuSettingsSection],
        [self cpuTraceDetailSection],
        [self cpuTraceTriggerSection],
    ];
    return cell;
}

+ (MTHawkeyeSettingSectionEntity *)cpuSettingsSection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"cpu-trace";
    primary.headerText = @"CPU Tracer";
    primary.footerText = @"";
    primary.cells = @[
        [self cpuMonitorSwitcherCell],
    ];
    return primary;
}

+ (MTHawkeyeSettingSectionEntity *)cpuTraceDetailSection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"cpu-trace";
    primary.headerText = @"CPU High Load Trace";
    primary.footerText = @"";
    primary.cells = @[
        [self ratioThresholdEditorCell],
        [self backtraceDumpThresholdEditorCell],
        [self lastDurationEditorCell],
    ];
    return primary;
}

+ (MTHawkeyeSettingSectionEntity *)cpuTraceTriggerSection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"";
    primary.headerText = @"Trace Trigger Frequency";
    primary.footerText = @"";
    primary.cells = @[
        [self checkIntervalIdleEditorCell],
        [self checkIntervalBusyEditorCell],
    ];
    return primary;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)cpuMonitorSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace High Load CPU";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].cpuTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].cpuTraceOn) {
            [MTHawkeyeUserDefaults shared].cpuTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)ratioThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"High load threshold";
    editor.inputTips = @"Only care when the CPU usage exceeding the threshold.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"%";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].cpuTraceHighLoadThreshold * 100;
        NSString *str = [NSString stringWithFormat:@"%.0f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue / 100.f;
        if (fabs(value - [MTHawkeyeUserDefaults shared].cpuTraceHighLoadThreshold) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].cpuTraceHighLoadThreshold = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)backtraceDumpThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"StackFrame dump threshold";
    editor.inputTips = @"Only dump StackFrame of the thread when it's CPU usage exceeding the threshold while sampling.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"%";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].cpuTraceStackFramesDumpThreshold * 100;
        NSString *str = [NSString stringWithFormat:@"%.0f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue / 100.f;
        if (fabs(value - [MTHawkeyeUserDefaults shared].cpuTraceStackFramesDumpThreshold) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].cpuTraceStackFramesDumpThreshold = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)lastDurationEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"High load lasting limit";
    editor.inputTips = @"Only generate record when the high load lasting longer than limit.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].cpuTraceHighLoadLastingLimit;
        NSString *str = [NSString stringWithFormat:@"%.0f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].cpuTraceHighLoadLastingLimit) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].cpuTraceHighLoadLastingLimit = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)checkIntervalIdleEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Trigger Interval (Low Load)";
    editor.inputTips = @"When the CPU is under low load, the frequency to check the CPU usage.";
    editor.editorKeyboardType = UIKeyboardTypeNumbersAndPunctuation;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalIdle;
        NSString *str = [NSString stringWithFormat:@"%.1f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalIdle) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalIdle = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)checkIntervalBusyEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Trigger Interval (High Load)";
    editor.inputTips = @"When the CPU is under high load, the frequency to check the CPU usage.";
    editor.editorKeyboardType = UIKeyboardTypeNumbersAndPunctuation;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalBusy;
        NSString *str = [NSString stringWithFormat:@"%.1f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalBusy) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].cpuTraceCheckIntervalBusy = value;
        return YES;
    };
    return editor;
}

@end
