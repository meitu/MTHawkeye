//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2020/11/13
// Created by: whw
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeAverageStorage : NSObject

+ (void)recordMem:(CGFloat)memory;
+ (void)recordCPU:(double)cpu;
+ (void)recordFPS:(int)fps;
+ (void)recordglFPS:(int)fps;

@end

NS_ASSUME_NONNULL_END
