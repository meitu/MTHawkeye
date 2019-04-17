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


#import "UITableView+MTHEmptyTips.h"


@implementation UITableView (MTHEmptyTips)

- (void)mthawkeye_removeEmptyTipsFooterView {
    self.tableFooterView = [UIView new];
}

- (UILabel *)mthawkeye_tipsLabelWithText:(NSString *)text top:(CGFloat)top {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textColor = [UIColor lightGrayColor];
    label.font = [UIFont systemFontOfSize:14];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = text;
    [label sizeToFit];
    label.frame = CGRectMake(40.f, top, CGRectGetWidth(self.bounds) - 40.f * 2, CGRectGetHeight(label.bounds));
    return label;
}

- (UIButton *)mthawkeye_buttonWithText:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn sizeToFit];
    return btn;
}

- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips {
    [self mthawkeye_setFooterViewWithEmptyTips:tips tipsTop:45.f];
}

#define kContentOffsetY 10.f;

- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips tipsTop:(CGFloat)tipsTop {
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectZero];
    UILabel *tipsLabel = [self mthawkeye_tipsLabelWithText:tips top:tipsTop];

    CGFloat footerHeight = tipsTop * 2 + CGRectGetHeight(tipsLabel.bounds) + kContentOffsetY;
    footerView.frame = CGRectMake(0, 0, self.bounds.size.width, footerHeight);

    [footerView addSubview:tipsLabel];
    self.tableFooterView = footerView;
}

- (void)mthawkeye_setFooterViewWithEmptyTips:(NSString *)tips
                                     tipsTop:(CGFloat)tipsTop
                                      button:(NSString *)title
                                   btnTarget:(id)target
                                   btnAction:(SEL)action {
    const CGFloat tipsBtnSpace = 16.f;

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectZero];
    UILabel *tipsLabel = [self mthawkeye_tipsLabelWithText:tips top:tipsTop];
    CGFloat tipsHeight = CGRectGetHeight(tipsLabel.bounds);

    UIButton *btn = [self mthawkeye_buttonWithText:title];
    CGFloat btnHeight = CGRectGetHeight(btn.bounds);

    btn.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.f, tipsTop + tipsHeight + tipsBtnSpace + btnHeight / 2.f);
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    CGFloat footerHeight = tipsTop * 2 + tipsHeight + tipsBtnSpace + btnHeight + kContentOffsetY;
    footerView.frame = CGRectMake(0, 0, self.bounds.size.width, footerHeight);

    [footerView addSubview:tipsLabel];
    [footerView addSubview:btn];
    self.tableFooterView = footerView;
}

@end
