//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 11/08/2017
// Created by: EuanC
//


#import "UIViewController+MTHawkeyeLayoutSupport.h"

@implementation UIViewController (MTHawkeyeLayoutSupport)

- (id<UILayoutSupport>)mt_hawkeye_navigationBarTopLayoutGuide {
    if (self.parentViewController && ![self.parentViewController isKindOfClass:UINavigationController.class]) {
        return self.parentViewController.mt_hawkeye_navigationBarTopLayoutGuide;
    } else {
        return self.topLayoutGuide;
    }
}

- (id<UILayoutSupport>)mt_hawkeye_navigationBarBottomLayoutGuide {
    if (self.parentViewController && ![self.parentViewController isKindOfClass:UINavigationController.class]) {
        return self.parentViewController.mt_hawkeye_navigationBarTopLayoutGuide;
    } else {
        return self.bottomLayoutGuide;
    }
}

@end
