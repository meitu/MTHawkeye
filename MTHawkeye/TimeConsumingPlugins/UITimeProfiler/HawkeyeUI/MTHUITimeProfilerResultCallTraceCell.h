//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/11/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHCallTraceTimeCostModel;

@interface MTHUITimeProfilerResultCallTraceCell : UITableViewCell

@property (nonatomic, strong) UILabel *timeCostLabel;
@property (nonatomic, strong) UILabel *callInfoLabel;
@property (nonatomic, strong, nullable) UILabel *subCallInfoLabel;

- (void)configureWithCallTraceTimeCostModel:(MTHCallTraceTimeCostModel *)model expanded:(BOOL)expanded;

+ (CGFloat)heightForCallTraceTimeCostModel:(MTHCallTraceTimeCostModel *)model expanded:(BOOL)expanded;

@end

NS_ASSUME_NONNULL_END
