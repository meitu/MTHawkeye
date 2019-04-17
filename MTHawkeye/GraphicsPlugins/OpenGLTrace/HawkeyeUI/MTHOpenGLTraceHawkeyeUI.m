//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/22
// Created by: EuanC
//


#import "MTHOpenGLTraceHawkeyeUI.h"
#import "MTHOpenGLTraceResultViewController.h"
#import "MTHawkeyeUserDefaults+OpenGLTrace.h"

#import <MTHawkeye/MTHMonitorViewCell.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/UIViewController+MTHawkeyeCurrentViewController.h>
#import "MTHOpenGLTraceHawkeyeAdaptor.h"


@interface MTHOpenGLTraceHawkeyeUI ()

@property (nonatomic, strong) MTHMonitorViewCell *cell;

@end


@implementation MTHOpenGLTraceHawkeyeUI

@synthesize delegate;
@synthesize widgetHidden = _widgetHidden;

- (instancetype)init {
    if ([super init]) {
        _widgetHidden = YES;
    }
    return self;
}

// MARK: - MTHawkeyeMainPanelPlugin
- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupGraphics;
}

- (NSString *)switchingOptionTitle {
    return @"OpenGL Tracer";
}

- (NSString *)mainPanelIdentity {
    return @"opengl-tracer";
}

- (UIViewController *)mainPanelViewController {
    return [[MTHOpenGLTraceResultViewController alloc] init];
}

// MARK: - MTHawkeyeFloatingWidgetPlugin
- (MTHMonitorViewCell *)widget {
    if (_cell == nil) {
        _cell = [[MTHMonitorViewCell alloc] init];
    }
    return _cell;
}

- (nonnull NSString *)widgetIdentity {
    return @"gl-tracer";
}

- (BOOL)widgetHidden {
    return _widgetHidden;
}

- (void)setWidgetHidden:(BOOL)widgetHidden {
    if (_widgetHidden == widgetHidden)
        return;

    _widgetHidden = widgetHidden;
    if (_widgetHidden) {
        if ([self.delegate respondsToSelector:@selector(floatingWidgetWantHidden:)])
            [self.delegate floatingWidgetWantHidden:self];
    } else {
        if ([self.delegate respondsToSelector:@selector(floatingWidgetWantShow:)])
            [self.delegate floatingWidgetWantShow:self];
    }
}


- (MTHawkeyeSettingSwitcherCellEntity *)floatingWidgetSwitcher {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];

    cell.title = @"GPU MEMORY";

    cell.frozen = ![[MTHawkeyeUserDefaults shared] openGLTraceOn];

    cell.setupValueHandler = ^BOOL {
        return [[MTHawkeyeUserDefaults shared] openGLTraceShowGPUMemoryOn];
    };

    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        [[MTHawkeyeUserDefaults shared] setOpenGLTraceShowGPUMemoryOn:newValue];
        self.widgetHidden = !newValue;
        return newValue;
    };

    return cell;
}

- (void)receivedFlushStatusCommand {
    if (!self.widgetHidden && (![[MTHawkeyeUserDefaults shared] openGLTraceOn] || ![[MTHawkeyeUserDefaults shared] openGLTraceShowGPUMemoryOn])) {
        self.widgetHidden = YES;
        return;
    }

    NSInteger mem = MTHOpenGLTraceHawkeyeAdaptor.openGLESResourceMemorySize;

    if ([[MTHawkeyeUserDefaults shared] openGLTraceShowGPUMemoryOn]) {
        if (!self.widgetHidden && mem == 0) {
            self.widgetHidden = YES;
        } else if (self.widgetHidden && mem > 0) {
            self.widgetHidden = NO;
        }
    }

    float memInMB = mem / 1024.f / 1024.f;
    NSString *memStr;
    if (memInMB > 1.0f) {
        memStr = [NSString stringWithFormat:@"%ld", (long)memInMB];
    } else {
        memStr = [NSString stringWithFormat:@"%.1lf", memInMB];
    }

    [self.cell updateWithValue:memStr unit:@"MB"];
}

- (void)receivedRaiseWarningCommand:(NSDictionary *)params {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGFloat duration = [params[kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey] floatValue];
        [self.cell flashingWithDuration:duration color:[UIColor redColor]];
    });
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupGraphics;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"OpenGL Trace";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [self glDebugDetailSettingsSection],
    ];
    return cell;
}

__weak MTHawkeyeSettingSwitcherCellEntity *weak_analysisSwitcherCell = nil;
__weak MTHawkeyeSettingSwitcherCellEntity *weak_exceptionSwitcherCell = nil;

+ (MTHawkeyeSettingSectionEntity *)glDebugDetailSettingsSection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"opengl-trace";
    primary.headerText = @"OpenGL";
    primary.footerText = @"OpenGL Trace Analysis depends on OpenGL Trace, which can analysis glfunctions and catch some errors.\n\n"
                         @"OpenGL Trace Exception depends on OpenGL Trace Analysis, which means if an error occur, Hawkeye will throw an error exception, otherwise you should implement MTHOpenGLTraceDelegate processing error by youself";

    MTHawkeyeSettingSwitcherCellEntity *onCell = [self gldebuggerOnSwitcherCell];
    MTHawkeyeSettingSwitcherCellEntity *analysisCell = [self analysisSwitcherCell];
    MTHawkeyeSettingSwitcherCellEntity *exceptionCell = [self exceptionSwitcherCell];
    if (![[MTHawkeyeUserDefaults shared] openGLTraceOn]) {
        analysisCell.frozen = YES;
        exceptionCell.frozen = YES;
    } else if (![[MTHawkeyeUserDefaults shared] openGLTraceAnalysisOn]) {
        exceptionCell.frozen = YES;
    }

    weak_analysisSwitcherCell = analysisCell;
    weak_exceptionSwitcherCell = exceptionCell;

    primary.cells = @[ onCell, analysisCell, exceptionCell ];
    return primary;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)gldebuggerOnSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"OpenGL Trace";
    entity.setupValueHandler = ^BOOL {
        BOOL value = [[MTHawkeyeUserDefaults shared] openGLTraceOn];
        return value;
    };

    __weak __typeof(entity) weak_entity = entity;
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue == [[MTHawkeyeUserDefaults shared] openGLTraceOn])
            return NO;

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                                 message:@"Relaunch needed to enable GLTrace"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *rebootAction =
            [UIAlertAction actionWithTitle:@"Relaunch"
                                     style:UIAlertActionStyleDestructive
                                   handler:^(UIAlertAction *_Nonnull action) {
                                       [MTHawkeyeUserDefaults shared].openGLTraceOn = newValue;

                                       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                                           exit(0);
                                       });
                                   }];
        UIAlertAction *cancelAction =
            [UIAlertAction actionWithTitle:@"Cancel"
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *_Nonnull action) {
                                       // revert ui
                                       if (weak_entity.delegate) {
                                           [weak_entity.delegate hawkeyeSettingEntityValueDidChanged:weak_entity];
                                       }
                                   }];
        [alertController addAction:cancelAction];
        [alertController addAction:rebootAction];

        [[UIViewController mth_topViewController] presentViewController:alertController animated:YES completion:nil];
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)analysisSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"OpenGL Trace Analysis";
    entity.setupValueHandler = ^BOOL {
        BOOL value = [MTHawkeyeUserDefaults shared].openGLTraceAnalysisOn;
        return value;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        [MTHawkeyeUserDefaults shared].openGLTraceAnalysisOn = newValue;

        // exception depend on analysis
        [MTHawkeyeUserDefaults shared].openGLTraceRaiseExceptionOn = newValue;

        weak_exceptionSwitcherCell.frozen = !newValue;
        if (weak_exceptionSwitcherCell.delegate) {
            [weak_exceptionSwitcherCell.delegate hawkeyeSettingEntityValueDidChanged:weak_exceptionSwitcherCell];
        }

        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)exceptionSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    weak_exceptionSwitcherCell = entity;
    entity.title = @"Raise Exception Enabled";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].openGLTraceRaiseExceptionOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        [MTHawkeyeUserDefaults shared].openGLTraceRaiseExceptionOn = newValue;
        return YES;
    };
    return entity;
}


// MARK: -

@end
