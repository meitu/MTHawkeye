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


#import <UIKit/UIKit.h>

@interface MTHPopoverViewController : UINavigationController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController fromSourceView:(UIView *)sourceView;

@end
