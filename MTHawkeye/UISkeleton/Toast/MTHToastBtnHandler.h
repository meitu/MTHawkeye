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


#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, MTHToastActionStyle) {
    MTHToastActionStyleLeft = 0,
    MTHToastActionStyleRight
};

typedef void (^MTHToastAction)(void);

@interface MTHToastBtnHandler : NSObject


+ (instancetype)actionWithTitle:(NSString *)title
                          style:(MTHToastActionStyle)style
                        handler:(MTHToastAction)handler;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) MTHToastActionStyle style;
@property (nonatomic, readonly) MTHToastAction handler;

@end
