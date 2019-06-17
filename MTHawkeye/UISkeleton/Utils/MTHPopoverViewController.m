//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/1
// Created by: 潘名扬
//


#import "MTHPopoverViewController.h"

@interface MTHPopoverViewController () <UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UIViewController *contentViewController;

@end

@implementation MTHPopoverViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController fromSourceView:(UIView *)sourceView {
    if ((self = [super initWithRootViewController:contentViewController])) {
        _contentViewController = contentViewController;
        self.modalPresentationStyle = UIModalPresentationPopover;
        self.popoverPresentationController.delegate = self;
        self.popoverPresentationController.sourceView = sourceView;
        self.popoverPresentationController.sourceRect = sourceView.bounds;
        self.popoverPresentationController.permittedArrowDirections = 0; // No Arrow
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self dimBackground];
}

- (CGSize)preferredContentSize {
    CGSize preferedSize = self.contentViewController.preferredContentSize;
    preferedSize.height += CGRectGetHeight(self.navigationBar.bounds);

    CGSize restrictedSize = CGSizeApplyAffineTransform([UIScreen mainScreen].bounds.size, CGAffineTransformMakeScale(0.95, 0.8));
    CGSize actualSize;
    if (preferedSize.height < DBL_EPSILON || preferedSize.width < DBL_EPSILON) {
        actualSize = restrictedSize;
    } else {
        actualSize = CGSizeMake(MIN(preferedSize.width, restrictedSize.width), MIN(preferedSize.height, restrictedSize.height));
    }
    return actualSize;
}

- (void)dimBackground {
    UIWindow *placeOnWindow = self.presentingViewController.view.window;
    if (!placeOnWindow) {
        return;
    }

    NSArray<UIView *> *arrayOfSubviews = placeOnWindow.subviews.lastObject.subviews;
    for (int i = 0; i < arrayOfSubviews.count; i++) {
        if ([NSStringFromClass(arrayOfSubviews[i].class) isEqualToString:@"_UIMirrorNinePatchView"]) {
            arrayOfSubviews[i].backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
            NSArray<UIImageView *> *arrayOfImageViews = arrayOfSubviews[i].subviews;
            for (int j = 0; j < arrayOfImageViews.count; j++) {
                arrayOfImageViews[j].image = nil;
            }
        }
    }
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

@end
