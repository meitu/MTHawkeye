//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 29/06/2018
// Created by: Huni
//


#import "MTHToastWindow.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@implementation MTHToastWindow

static MTHToastWindow *sharedWindow;

+ (instancetype)sharedWindow {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedWindow = [[self alloc] initWithFrame:CGRectZero];
        [sharedWindow bringWindowToTop];
        sharedWindow.layer.masksToBounds = NO;
        [sharedWindow makeKeyAndVisible];
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
        sharedWindow.rootViewController = vc;
    });
    return sharedWindow;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    __block UIView *view;
    [self.rootViewController.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if (CGRectContainsPoint(obj.frame, point)) {
            view = obj;
        }
    }];
    if (view) {
        CGPoint point1 = [self convertPoint:point toView:view];
        return [view hitTest:point1 withEvent:event];
    } else {
        return [super hitTest:point withEvent:event];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"frame"] && !CGRectEqualToRect(self.frame, CGRectZero)) {
        self.frame = CGRectZero;
    }
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"frame"];
}

- (void)bringWindowToTop {
    CGFloat highestWindowLevel = [self highestWindowLevel];
    // 防止溢出
    if (highestWindowLevel + 1 > highestWindowLevel) {
        self.windowLevel = highestWindowLevel + 1;
    } else {
        self.windowLevel = CGFLOAT_MAX;
    }
}

- (CGFloat)highestWindowLevel {
    CGFloat highestLevel = UIWindowLevelAlert;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.windowLevel > highestLevel) {
            highestLevel = window.windowLevel;
        }
    }
    return highestLevel;
}

// MARK: - Private API
// 防止干扰主程序的状态栏样式，
- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}

- (BOOL)_canBecomeKeyWindow {
    return NO;
}

@end
