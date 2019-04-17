//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/9/11
// Created by: EuanC
//


#import <UIKit/UIKit.h>

@interface UITableView (MTHEmptyTips)

- (void)mthawkeye_removeEmptyTipsFooterView;
- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips;

- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips tipsTop:(CGFloat)top;

- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips
                                     tipsTop:(CGFloat)tipsTop
                                      button:(NSString *)title
                                   btnTarget:(id)target
                                   btnAction:(SEL)action;

@end
