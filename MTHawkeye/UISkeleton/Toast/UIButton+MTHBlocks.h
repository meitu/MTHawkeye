//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 11/06/2018
// Created by: Huni
//


#import <UIKit/UIKit.h>

typedef void (^MTHToastButtonActionBlock)(void);

@interface UIButton (MTHBlocks)

- (void)mth_handleControlEvent:(UIControlEvents)controlEvent
                     withBlock:(MTHToastButtonActionBlock)action;

@end
