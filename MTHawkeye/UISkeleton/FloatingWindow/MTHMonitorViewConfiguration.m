//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 02/12/2017
// Created by: EuanC
//


#import "MTHMonitorViewConfiguration.h"

#import <MTHawkeye/MTHawkeyeUserDefaults.h>


static NSString *const kHawkeyeMonitorViewOrigin = @"floating-widgets-origin";

static const CGFloat kMonitorWidth = 42;
static const CGFloat kMonitorCellHeight = 14;

@implementation MTHMonitorViewConfiguration

static CGFloat _monitorWidth = kMonitorWidth;
static CGFloat _monitorCellHeight = kMonitorCellHeight;

static CGPoint _monitorInitPosition = {};

static UIFont *_valueFont = nil;
static UIFont *_unitFont = nil;

static UIColor *_valueColor = nil;
static UIColor *_unitColor = nil;

+ (void)initialize {
    _valueFont = [self fontWithSize:12];
}

+ (void)setValueFont:(UIFont *)valueFont {
    _valueFont = valueFont;
}

+ (UIFont *)valueFont {
    if (_valueFont == nil) {
        _valueFont = [self fontWithSize:12];
    }
    return _valueFont;
}

+ (void)setUnitFont:(UIFont *)unitFont {
    _unitFont = unitFont;
}

+ (UIFont *)unitFont {
    if (_unitFont == nil) {
        _unitFont = [self fontWithSize:7];
    }
    return _unitFont;
}

+ (void)setValueColor:(UIColor *)valueColor {
    _valueColor = valueColor;
}

+ (UIColor *)valueColor {
    if (_valueColor == nil) {
        _valueColor = [UIColor whiteColor];
    }
    return _valueColor;
}

+ (void)setUnitColor:(UIColor *)unitColor {
    _unitColor = unitColor;
}

+ (UIColor *)unitColor {
    if (_unitColor == nil) {
        _unitColor = [UIColor whiteColor];
    }
    return _unitColor;
}

+ (CGFloat)monitorCellHeight {
    return _monitorCellHeight;
}

+ (void)setMonitorCellHeight:(CGFloat)monitorCellHeight {
    _monitorCellHeight = monitorCellHeight;
}

+ (CGFloat)monitorWidth {
    return _monitorWidth;
}

+ (void)setMonitorWidth:(CGFloat)monitorWidth {
    _monitorWidth = monitorWidth;
}

+ (CGPoint)monitorInitPosition {
    if (CGPointEqualToPoint(CGPointZero, _monitorInitPosition)) {
        id cache = [[MTHawkeyeUserDefaults shared] objectForKey:kHawkeyeMonitorViewOrigin];
        if ([cache isKindOfClass:[NSString class]]) {
            _monitorInitPosition = CGPointFromString(cache);
        } else {
            _monitorInitPosition = CGPointMake(0, [UIScreen mainScreen].bounds.size.width / 2);
        }
    }
    return _monitorInitPosition;
}

+ (void)setMonitorInitPosition:(CGPoint)monitorInitPosition {
    _monitorInitPosition = CGPointMake(monitorInitPosition.x < 0 ? 0 : monitorInitPosition.x,
        monitorInitPosition.y < 0 ? 0 : monitorInitPosition.y);
    [[MTHawkeyeUserDefaults shared] setObject:NSStringFromCGPoint(_monitorInitPosition) forKey:kHawkeyeMonitorViewOrigin];
}

+ (UIFont *)fontWithSize:(NSInteger)size {
    UIFont *font = [UIFont fontWithName:@"Menlo" size:size];
    if (!font) {
        font = [UIFont fontWithName:@"Courier" size:size];
    }
    return font;
}

@end
