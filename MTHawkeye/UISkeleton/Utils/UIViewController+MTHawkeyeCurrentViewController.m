//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 02/07/2018
// Created by: Huni
//


#import "UIViewController+MTHawkeyeCurrentViewController.h"

@implementation UIViewController (MTHawkeyeCurrentViewController)

+ (UIViewController *)mth_topViewController {
    UIViewController *topController = [[self mth_topWindow] rootViewController];
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;

        if ([topController isKindOfClass:[UINavigationController class]]) {
            topController = [(UINavigationController *)topController visibleViewController];
        } else if ([topController isKindOfClass:[UITabBarController class]]) {
            topController = [(UITabBarController *)topController selectedViewController];
        }
    }
    return topController;
}

+ (UIWindow *)mth_topWindow {
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in [windows reverseObjectEnumerator]) {
        if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) {
            continue;
        }
        if (!window.isHidden && [window isKindOfClass:[UIWindow class]] && CGRectEqualToRect(window.bounds, [UIScreen mainScreen].bounds))
            return window;
    }
    return [[UIApplication sharedApplication].delegate window];
}

@end
