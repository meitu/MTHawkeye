//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/24
// Created by: EuanC
//


#import "MTHUITimeProfilerHawkeyeUI.h"
#import "MTHTimeIntervalRecorder.h"
#import "MTHUITimeProfilerHawkeyeAdaptor.h"
#import "MTHUITimeProfilerResultViewController.h"
#import "MTHawkeyeUserDefaults+ObjcCallTrace.h"
#import "MTHawkeyeUserDefaults+UITimeProfiler.h"

#import <MTHawkeye/MTHToast.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/MTHawkeyeUIClient.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+UISkeleton.h>
#import <MTHawkeye/UIViewController+MTHawkeyeCurrentViewController.h>


@implementation MTHUITimeProfilerHawkeyeUI

- (void)dealloc {
    [self unobserveFirstVCDidAppeared];
}

- (instancetype)init {
    if (self = [super init]) {
        [self observeFirstVCDidAppeared];
    }
    return self;
}

- (void)observeFirstVCDidAppeared {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(firstVCDidAppeared:)
               name:kMTHawkeyeNotificationNameFirstVCDidAppeared
             object:nil];
}

- (void)unobserveFirstVCDidAppeared {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMTHawkeyeNotificationNameFirstVCDidAppeared object:nil];
}

- (void)firstVCDidAppeared:(NSNotification *)notification {
    if (![MTHawkeyeUserDefaults shared].displayFloatingWindow)
        return;

    MTHViewControllerAppearRecord *firstVCAppearedRecord = notification.userInfo[@"vc"];
    if (!firstVCAppearedRecord)
        return;

    NSTimeInterval firstObjcLoadTime = [MTHTimeIntervalRecorder shared].launchRecord.firstObjcLoadStartTime;
    NSTimeInterval afterFirstObjcLoadCost = (firstVCAppearedRecord.viewDidAppearExitTime - firstObjcLoadTime) * 1000.f;

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [[MTHToast shared] showToastWithMessage:[NSString stringWithFormat:@"Warm start ≈ %.1fms", afterFirstObjcLoadCost]
                                        handler:^{
                                            [[MTHawkeyeUIClient shared] showMainPanelWithSelectedID:[self mainPanelIdentity]];
                                        }];
    });
}

// MARK: - MTHawkeyeMainPanelPlugin
- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupTimeConsuming;
}

- (NSString *)switchingOptionTitle {
    return @"UI Time Profiler";
}

- (NSString *)mainPanelIdentity {
    return @"ui-time-profiler";
}

- (UIViewController *)mainPanelViewController {
    return [[MTHUITimeProfilerResultViewController alloc] init];
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupTimeConsuming;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"UI Time Profiler";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [MTHUITimeProfilerHawkeyeUI vcLifeTraceSection],
        [MTHUITimeProfilerHawkeyeUI objcCalltraceSection]
    ];
    return cell;
}

+ (MTHawkeyeSettingSectionEntity *)vcLifeTraceSection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"vc-life-trace";
    section.headerText = @"Trace ViewController Life";
    section.footerText = @"";
    section.cells = @[
        [MTHUITimeProfilerHawkeyeUI vcLifeTraceSwitcherCell]
    ];
    return section;
}

+ (MTHawkeyeSettingSectionEntity *)objcCalltraceSection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"objc-call-trace";
    section.headerText = @"Objective-C Call Trace";
    section.footerText = @"Objective-C method call trace is only for main thread, and will cover the backtrace, turn if off when unnecessary.";
    section.cells = @[
        [MTHUITimeProfilerHawkeyeUI objcTraceSwitcherCell],
        [MTHUITimeProfilerHawkeyeUI objcCallTraceThresholdEditorCell],
        [MTHUITimeProfilerHawkeyeUI objcCallTraceDepthLimitEditorCell]
    ];
    return section;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)vcLifeTraceSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace VC Life (Need Relaunch)";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].vcLifeTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].vcLifeTraceOn) {
            [MTHawkeyeUserDefaults shared].vcLifeTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)objcTraceSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace ObjC Call (Need Relaunch)";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].objcCallTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].objcCallTraceOn) {
            [MTHawkeyeUserDefaults shared].objcCallTraceOn = newValue;
        }

        NSNumber *value = [[MTHawkeyeUserDefaults shared] objectForKey:@"com.meitu.hawkeye.calltrace.on.isAlert"];
        if (newValue && (value ? !value.boolValue : YES)) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:@"ObjC Method Time Trace will cover backtrace frames, you should only turn on this when necessary" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            UIViewController *topController = [UIViewController mth_topViewController];
            [topController presentViewController:alert animated:YES completion:nil];
            [[MTHawkeyeUserDefaults shared] setObject:@(YES) forKey:@"com.meitu.hawkeye.calltrace.on.isAlert"];
        }

        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)objcCallTraceThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"ObjC Call Trace Threshold";
    editor.inputTips = @"Only Objective-C method that exceed the threshold on the main thread will be record.";
    editor.editorKeyboardType = UIKeyboardTypeNumbersAndPunctuation;
    editor.valueUnits = @"ms";
    editor.setupValueHandler = ^NSString *_Nonnull {
        CGFloat threshold = [MTHawkeyeUserDefaults shared].objcCallTraceTimeThresholdInMS;
        NSString *str = [NSString stringWithFormat:@"%.2f", threshold];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        CGFloat value = newValue.floatValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].objcCallTraceTimeThresholdInMS) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].objcCallTraceTimeThresholdInMS = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)objcCallTraceDepthLimitEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"ObjC Call Trace Depth Limit";
    editor.inputTips = @"Method depth in stack that exceed the limit will not be logged.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSInteger threshold = [MTHawkeyeUserDefaults shared].objcCallTraceDepthLimit;
        NSString *str = [NSString stringWithFormat:@"%@", @(threshold)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSInteger value = newValue.integerValue;
        if (value != [MTHawkeyeUserDefaults shared].objcCallTraceDepthLimit)
            [MTHawkeyeUserDefaults shared].objcCallTraceDepthLimit = value;
        return YES;
    };
    return editor;
}

@end
