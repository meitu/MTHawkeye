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


#import "MTHDirectoryWatcherHawkeyeUI.h"

#import "FLEXHawkeyePlugin.h"
#import "MTHDirectoryTree.h"
#import "MTHDirectoryWatcherSelctionViewController.h"
#import "MTHDirectoryWatcherViewController.h"
#import "MTHawkeyeSettingTableEntity.h"
#import "MTHawkeyeUserDefaults+DirectorWatcher.h"
#import "UIViewController+MTHawkeyeCurrentViewController.h"


@implementation MTHDirectoryWatcherHawkeyeUI

+ (void)initialize {
    [FLEXHawkeyePlugin addAirDropMenuForFileBrowserViewController];
}

// MARK: - MTHawkeyeMainPanelPlugin
- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupStorage;
}

- (NSString *)switchingOptionTitle {
    return @"Directory Watcher";
}

- (NSString *)mainPanelIdentity {
    return @"directory-watcher";
}

- (UIViewController *)mainPanelViewController {
    return [[MTHDirectoryWatcherViewController alloc] init];
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupStorage;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"Directory Watcher";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [MTHDirectoryWatcherHawkeyeUI watcherMainSection],
        [MTHDirectoryWatcherHawkeyeUI watcherDetectOptionSection],
        [MTHDirectoryWatcherHawkeyeUI watcherPathSection],
    ];
    return cell;
}

#pragma mark - Sections
+ (MTHawkeyeSettingSectionEntity *)watcherMainSection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"directory-watcher-main";
    section.headerText = @"Directory Watcher";
    section.footerText = @"";
    section.cells = @[
        [MTHDirectoryWatcherHawkeyeUI dirWatcherSwitcherCell]
    ];
    return section;
}

+ (MTHawkeyeSettingSectionEntity *)watcherDetectOptionSection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"directory-watcher-options";
    section.headerText = @"Detect Options";
    section.footerText = @"";
    section.cells = @[
        [MTHDirectoryWatcherHawkeyeUI stratDelayEditorCell],
        [MTHDirectoryWatcherHawkeyeUI reportMinIntervalEditorCell],
        [MTHDirectoryWatcherHawkeyeUI resetEnterForegroundSwitcherCell],
        [MTHDirectoryWatcherHawkeyeUI resetEnterBackgroundSwitcherCell],
        [MTHDirectoryWatcherHawkeyeUI stopWatcherAfterTimesEditorCell]
    ];
    return section;
}

+ (MTHawkeyeSettingSectionEntity *)watcherPathSection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"directory-watcher-paths";
    section.headerText = @"More Options";
    section.footerText = @"";

    MTHawkeyeSettingActionCellEntity *addPathCell = [[MTHawkeyeSettingActionCellEntity alloc] init];
    addPathCell.title = @"Edit Watching Directory Path";
    addPathCell.didTappedHandler = ^{
        MTHDirectoryWatcherSelctionViewController *selectVC = [[MTHDirectoryWatcherSelctionViewController alloc]
            initWithRootData:@[ [[MTHDirectoryTree alloc] initWithRelativePath:MTHDirectoryTreeDocument],
                [[MTHDirectoryTree alloc] initWithRelativePath:MTHDirectoryTreeCaches],
                [[MTHDirectoryTree alloc] initWithRelativePath:MTHDirectoryTreePreferences],
                [[MTHDirectoryTree alloc] initWithRelativePath:MTHDirectoryTreeTmp] ]
                showWatching:YES];

        UIViewController *topViewController = [UIViewController mth_topViewController];
        if (topViewController.navigationController) {
            [topViewController.navigationController pushViewController:selectVC animated:YES];
        } else {
            [topViewController presentViewController:selectVC animated:YES completion:nil];
        }
    };
    section.cells = @[ addPathCell ];
    return section;
}

#pragma mark - Cells
+ (MTHawkeyeSettingSwitcherCellEntity *)dirWatcherSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Directory Watcher";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].directoryWatcherOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].directoryWatcherOn) {
            [MTHawkeyeUserDefaults shared].directoryWatcherOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)stratDelayEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Start Delay";
    editor.inputTips = @"";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSTimeInterval delayTime = [MTHawkeyeUserDefaults shared].directoryWatcherStartDelay;
        NSString *str = [NSString stringWithFormat:@"%0.2f", delayTime];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSTimeInterval value = newValue.doubleValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].directoryWatcherStartDelay) < DBL_EPSILON)
            [MTHawkeyeUserDefaults shared].directoryWatcherStartDelay = value;
        return YES;
    };
    return editor;
}

#pragma mark--
+ (MTHawkeyeSettingSwitcherCellEntity *)resetEnterForegroundSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trigger When Enter Foreground";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions & kMTHDirectoryWatcherDetectTimingEnterForeground;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue) {
            [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions |= kMTHDirectoryWatcherDetectTimingEnterForeground;
        } else {
            [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions &= ~kMTHDirectoryWatcherDetectTimingEnterForeground;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)resetEnterBackgroundSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trigger When Enter Background";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions & kMTHDirectoryWatcherDetectTimingEnterBackground;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue) {
            [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions |= kMTHDirectoryWatcherDetectTimingEnterBackground;
        } else {
            [MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions &= ~kMTHDirectoryWatcherDetectTimingEnterBackground;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)stopWatcherAfterTimesEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Trigger Limit Times";
    editor.inputTips = @"";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSUInteger stopAfter = [MTHawkeyeUserDefaults shared].directoryWatcherStopAfterTimes;
        NSString *str = [NSString stringWithFormat:@"%@", @(stopAfter)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSUInteger value = newValue.integerValue;
        if (value != [MTHawkeyeUserDefaults shared].directoryWatcherStopAfterTimes) {
            [MTHawkeyeUserDefaults shared].directoryWatcherStopAfterTimes = value;
        }
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)reportMinIntervalEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Trigger Interval";
    editor.inputTips = @"";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"s";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSTimeInterval minInterval = [MTHawkeyeUserDefaults shared].directoryWatcherReportMinInterval;
        NSString *str = [NSString stringWithFormat:@"%0.2f", minInterval];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSTimeInterval value = newValue.doubleValue;
        if (fabs(value - [MTHawkeyeUserDefaults shared].directoryWatcherReportMinInterval) < DBL_EPSILON) {
            [MTHawkeyeUserDefaults shared].directoryWatcherReportMinInterval = value;
        }
        return YES;
    };
    return editor;
}


@end
