//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/15
// Created by: EuanC
//


#import "MTFPSHawkeyeUI.h"
#import "MTFPSHawkeyeAdaptor.h"
#import "MTHFPSTrace.h"
#import "MTHawkeyeUserDefaults+UISkeleton.h"

#import <MTHawkeye/MTHMonitorViewCell.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>


@interface MTFPSHawkeyeUI () <MTHFPSTraceDelegate>

@property (nonatomic, strong) MTHMonitorViewCell *cell;
@property (nonatomic, assign) BOOL widgetHidden;

@end


@implementation MTFPSHawkeyeUI

@synthesize delegate;
@synthesize widgetHidden = _widgetHidden;

- (instancetype)init {
    if (self = [super init]) {
        _widgetHidden = [self widgetHiddenDefault];
        [[MTHFPSTrace shared] addDelegate:self];
    }
    return self;
}

// MARK: - UserDefaults
- (BOOL)widgetHiddenDefault {
    NSNumber *display = [[MTHawkeyeUserDefaults shared] objectForKey:@"displayFPS"];
    return display ? !display.boolValue : NO;
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

    [[MTHawkeyeUserDefaults shared] setObject:@(!widgetHidden) forKey:@"displayFPS"];
}

// MARK: - MTHawkeyeFloatingWidgetDisplaySwitcherPlugin
- (MTHawkeyeSettingSwitcherCellEntity *)floatingWidgetSwitcher {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Display FPS";
    cell.setupValueHandler = ^BOOL {
        return !self.widgetHidden;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (self.widgetHidden == (!newValue))
            return NO;

        self.widgetHidden = !newValue;
        return YES;
    };

    return cell;
}

// MARK: MTHawkeyeFloatingWidgetPlugin

- (MTHMonitorViewCell *)widget {
    if (_cell == nil) {
        _cell = [[MTHMonitorViewCell alloc] init];
    }
    return _cell;
}

- (BOOL)widgetHidden {
    return _widgetHidden;
}

- (nonnull NSString *)widgetIdentity {
    return @"fps/gpuimage-fps";
}

- (void)receivedRaiseWarningCommand:(NSDictionary *)params {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGFloat duration = [params[kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey] floatValue];
        [self.cell flashingWithDuration:duration color:[UIColor redColor]];
    });
}


// MARK: - MTHFPSMonitorDelegate

- (void)fpsValueDidChanged:(NSInteger)FPSValue {
    NSString *fpsStr = [NSString stringWithFormat:@"%@", @(FPSValue)];
    [self updateFPSWith:fpsStr];
}

- (void)gpuImageDisplayingChanged:(BOOL)isDisplay {
    [self updateGPUImageFPSWith:nil];
}

- (void)gpuImageFPSValueDidChanged:(NSInteger)gpuImageFPSValue {
    NSString *fpsStr = [NSString stringWithFormat:@"%@", @(gpuImageFPSValue)];
    [self updateGPUImageFPSWith:fpsStr];
}

// MARK: - view update
- (void)updateFPSWith:(NSString *)fps {
    [self updateFPSInfoWith:fps gpuImageFPS:nil];
}

- (void)updateGPUImageFPSWith:(NSString *)gpuImageFPS {
    if ([MTHFPSTrace shared].gpuImageViewDisplaying && [MTHFPSTrace shared].gpuImageFPSValue > 0) {
        [self updateFPSInfoWith:nil gpuImageFPS:gpuImageFPS];
    } else {
        // - 为特殊字符
        [self updateFPSInfoWith:nil gpuImageFPS:@"-"];
    }
}

- (void)updateFPSInfoWith:(NSString *)fps gpuImageFPS:(NSString *)gpuImageFPS {
    static NSString *cacheFPS, *cacheGPUImageFPS = @"-";
    if (fps) {
        cacheFPS = fps;
    }
    if (gpuImageFPS) {
        if ([cacheGPUImageFPS isEqualToString:@"-"] && [gpuImageFPS isEqualToString:@"-"]) {
            return;
        }
        cacheGPUImageFPS = gpuImageFPS;
    }

    NSString *infoString;
    if ([cacheGPUImageFPS isEqualToString:@"-"]) {
        infoString = cacheFPS ?: @"";
    } else {
        infoString = [NSString stringWithFormat:@"%@/%@", cacheFPS, cacheGPUImageFPS];
    }
    [self.cell updateWithString:infoString];
}

@end
