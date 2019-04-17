//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 03/09/2018
// Created by: Huni
//


#import "MTHToastBtnHandler.h"

@interface MTHToastBtnHandler ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) MTHToastActionStyle style;
@property (nonatomic, copy) MTHToastAction handler;

@end

@implementation MTHToastBtnHandler

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(MTHToastActionStyle)style
                        handler:(MTHToastAction)handler {
    MTHToastBtnHandler *action = [[MTHToastBtnHandler alloc] init];
    action.title = title;
    action.style = style;
    action.handler = handler;
    return action;
}

@end
