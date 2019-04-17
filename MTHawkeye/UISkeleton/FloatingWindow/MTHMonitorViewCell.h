//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

@interface MTHMonitorViewCell : UITableViewCell

@property (nonatomic, strong, readonly) UILabel *infoLabel;

- (instancetype)init;

- (void)updateWithString:(NSString *)content;
- (void)updateWithString:(NSString *)content color:(UIColor *)color;

- (void)updateWithValue:(NSString *)value unit:(NSString *)unit;
- (void)updateWithValue:(NSString *)value
             valueColor:(UIColor *)valueColor
                   unit:(NSString *)unit
              unitColor:(UIColor *)unitColor;

- (void)updateWithAttributeString:(NSAttributedString *)content;

- (void)flashingWithDuration:(CGFloat)durationInSeconds color:(UIColor *)flashColor;

@end
