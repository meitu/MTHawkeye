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


#import "MTHawkeyeBuildinFloatingWidget.h"
#import "MTHMonitorViewCell.h"
#import "MTHMonitorViewConfiguration.h"
#import "MTHawkeyeSettingTableEntity.h"
#import "MTHawkeyeUserDefaults+UISkeleton.h"

#import <MTHawkeye/MTHawkeyeAppStat.h>


// MARK: -
@interface MTHawkeyeMemoryStatFloatingWidget ()

@property (nonatomic, strong) MTHMonitorViewCell *cell;

@property (nonatomic, assign) NSInteger preMemFootPrint;

@end

@implementation MTHawkeyeMemoryStatFloatingWidget

@synthesize delegate;
@synthesize widgetHidden = _widgetHidden;

- (instancetype)init {
    if ((self = [super init])) {
        _widgetHidden = [self widgetHiddenDefault];
    }
    return self;
}

- (nonnull NSString *)widgetIdentity {
    return @"mem";
}

- (MTHMonitorViewCell *)widget {
    if (_cell == nil) {
        _cell = [[MTHMonitorViewCell alloc] init];
    }
    return _cell;
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

    [[MTHawkeyeUserDefaults shared] setObject:@(!widgetHidden) forKey:@"displayMEM"];
}

- (BOOL)widgetHiddenDefault {
    NSNumber *display = [[MTHawkeyeUserDefaults shared] objectForKey:@"displayMEM"];
    return display ? !display.boolValue : NO;
}

- (void)receivedFlushStatusCommand {
    NSInteger fp = (NSInteger)round(MTHawkeyeAppStat.memory / 1024 / 1024.f);
    if (self.preMemFootPrint == fp)
        return;

    self.preMemFootPrint = fp;
    NSString *memStr = [NSString stringWithFormat:@"%ld", (long)fp];

    [self.cell updateWithValue:memStr valueColor:nil unit:@"MB" unitColor:nil];
}

- (void)receivedRaiseWarningCommand:(NSDictionary *)params {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGFloat duration = [params[kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey] floatValue];
        [self.cell flashingWithDuration:duration color:[UIColor redColor]];
    });
}

- (MTHawkeyeSettingSwitcherCellEntity *)floatingWidgetSwitcher {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Display Memory";
    cell.setupValueHandler = ^BOOL {
        return !self.widgetHidden;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (self.widgetHidden == !newValue)
            return NO;

        self.widgetHidden = !newValue;
        return YES;
    };
    return cell;
}

@end


// MARK: - CPU Stat Widget
@interface MTHawkeyeCPUStatFloatingWidget ()

@property (nonatomic, strong) MTHMonitorViewCell *cell;

@end


@implementation MTHawkeyeCPUStatFloatingWidget

@synthesize delegate;
@synthesize widgetHidden = _widgetHidden;

- (instancetype)init {
    if ((self = [super init])) {
        _widgetHidden = [self widgetHiddenDefault];
    }
    return self;
}

- (nonnull NSString *)widgetIdentity {
    return @"cpu";
}

- (MTHMonitorViewCell *)widget {
    if (_cell == nil) {
        _cell = [[MTHMonitorViewCell alloc] init];
    }
    return _cell;
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

    [[MTHawkeyeUserDefaults shared] setObject:@(!widgetHidden) forKey:@"displayCPU"];
}

- (BOOL)widgetHiddenDefault {
    NSNumber *display = [[MTHawkeyeUserDefaults shared] objectForKey:@"displayCPU"];
    return display ? !display.boolValue : NO;
}

- (void)receivedFlushStatusCommand {
    static NSInteger preCpuUsage = 0;
    NSInteger cpuUsage = MTHawkeyeAppStat.cpuUsedByAllThreads * 100.f;
    if (preCpuUsage == cpuUsage)
        return;

    preCpuUsage = cpuUsage;
    NSString *cpuStr = [NSString stringWithFormat:@"%ld", (long)cpuUsage];
    [self.cell updateWithValue:cpuStr valueColor:nil unit:@"%" unitColor:nil];
}

- (void)receivedRaiseWarningCommand:(NSDictionary *)params {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGFloat duration = [params[kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey] floatValue];
        [self.cell flashingWithDuration:duration color:[UIColor redColor]];
    });
}

- (MTHawkeyeSettingSwitcherCellEntity *)floatingWidgetSwitcher {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Display CPU";
    cell.setupValueHandler = ^BOOL {
        return !self.widgetHidden;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (self.widgetHidden == !newValue)
            return NO;

        self.widgetHidden = !newValue;
        return YES;
    };
    return cell;
}

@end
