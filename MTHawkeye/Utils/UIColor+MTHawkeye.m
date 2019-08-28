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


#import "UIColor+MTHawkeye.h"

@implementation UIColor (MTHawkeye)

+ (UIColor *)mth_dynamicComplementaryColor:(UIColor *)defaultColor {
    CGFloat rgba[4];
    [defaultColor getRed:rgba green:rgba + 1 blue:rgba + 2 alpha:rgba + 3];
    
    return [self mth_dynamicLightColor:defaultColor
                             darkColor:[UIColor colorWithRed:1.0 - rgba[0]
                                                       green:1.0 - rgba[1]
                                                        blue:1.0 - rgba[2]
                                                       alpha:rgba[3]]];
}

+ (UIColor *)mth_dynamicLightColor:(UIColor *)lightColor darkColor:(UIColor *)darkColor {
    UIColor *color = lightColor;
    
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        color = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return darkColor;
            }
            return lightColor;
        }];
    }
#endif
    
    return color;
}

@end
