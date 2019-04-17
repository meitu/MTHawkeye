//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 04/07/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

@protocol MTHMonitorChartViewDelegate;

@interface MTHMonitorChartView : UIView

@property (weak, nonatomic) id<MTHMonitorChartViewDelegate> delegate;

@property (copy, nonatomic) NSString *unitLabelTitle;

- (void)reloadData;

@end


@protocol MTHMonitorChartViewDelegate <NSObject>

@required
- (NSInteger)numberOfPointsInChartView:(MTHMonitorChartView *)chartView;

- (CGFloat)chartView:(MTHMonitorChartView *)chartView valueForPointAtIndex:(NSInteger)index;

@optional

- (BOOL)rangeSelectEnableForChartView:(MTHMonitorChartView *)chartView;

- (void)chartView:(MTHMonitorChartView *)chartView didSelectedWithIndexRange:(NSRange)indexRange;

@end
