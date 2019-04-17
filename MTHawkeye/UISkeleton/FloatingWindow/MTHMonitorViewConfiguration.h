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


#import <Foundation/Foundation.h>

@interface MTHMonitorViewConfiguration : NSObject

@property (nonatomic, assign, class) CGFloat monitorWidth;
@property (nonatomic, assign, class) CGFloat monitorCellHeight;

@property (nonatomic, strong, class) UIFont *valueFont;
@property (nonatomic, strong, class) UIColor *valueColor;
@property (nonatomic, strong, class) UIFont *unitFont;
@property (nonatomic, strong, class) UIColor *unitColor;

@property (nonatomic, assign, class) CGPoint monitorInitPosition;

@end
