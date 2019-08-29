//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/8/15
// Created by: David.Dai
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (MTHawkeye)

/**
 *  Dynamic Complementary Color
 *
 *  @param  defaultColor  the color using on light mode
 *  @return will return a dynamic color [1.0 - R, 1.0 - G, 1.0 - B, A] when iOS13 dark mode
 */
+ (UIColor *)mth_dynamicComplementaryColor:(UIColor *)defaultColor;

/**
 *  dynamic color
 *
 *  @param  lightColor  the color using in light mode
 *  @param  darkColor  the color using in drak mode
 *  @return when ios will provide a dynamic color using ios13 new api [UIColor colorWithDynamicProvider:], else return lightColor
 */
+ (UIColor *)mth_dynamicLightColor:(UIColor *)lightColor darkColor:(UIColor *)darkColor;

@end

NS_ASSUME_NONNULL_END
