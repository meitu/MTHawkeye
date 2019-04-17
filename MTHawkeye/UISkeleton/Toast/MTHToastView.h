//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/06/2018
// Created by: Huni
//


#import <UIKit/UIKit.h>

#import "MTHToastViewMaker.h"
#import "UIButton+MTHBlocks.h"

typedef void (^MTHToastViewBlock)(void);

@interface MTHToastView : UIView

@property (copy, nonatomic) MTHToastViewBlock hiddenBlock;
@property (copy, nonatomic) MTHToastViewBlock clickedBlock;

+ (instancetype)toastViewFrom:(void (^)(MTHToastViewMaker *make))block;

- (void)showToastView;
- (void)hideToastView;

- (void)setupLeftButtonWithTitle:(NSString *)title
                        andEvent:(MTHToastButtonActionBlock)event;
- (void)setupRightButtonWithTitle:(NSString *)title
                         andEvent:(MTHToastButtonActionBlock)event;

- (void)pauseTimer;
- (void)startTimer;


@end
