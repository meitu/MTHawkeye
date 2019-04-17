//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/19
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>

typedef void (^MTHCallTraceShowDetailBlock)(void);

@interface MTHUITimeProfilerResultSectionHeaderView : UITableViewHeaderFooterView

@property (nonatomic, strong) UILabel *topLabel;
@property (nonatomic, strong) UILabel *bottomLabel;
@property (nonatomic, strong) MTHCallTraceShowDetailBlock showDetailBlock;

- (void)setupWithTopText:(NSString *)topText bottomText:(NSString *)bottomText showDetailBlock:(MTHCallTraceShowDetailBlock)block;

@end
