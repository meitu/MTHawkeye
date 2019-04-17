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


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MTHToastViewStyle) {
    MTHToastViewStyleSimple = 0,
    MTHToastViewStyleDetail
};

@interface MTHToastViewMaker : NSObject

@property (nonatomic, assign) MTHToastViewStyle style;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *shortContent;
@property (nonatomic, copy) NSString *longContent;
@property (nonatomic, assign) NSTimeInterval stayDuration;
@property (nonatomic, assign) BOOL expendHidden;

@end
