//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/9
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHTimeIntervalCustomEventRecord;

@interface MTHUITImeProfilerResultEventCell : UITableViewCell

- (void)configureWithEventRecord:(MTHTimeIntervalCustomEventRecord *)eventRecord
                        expanded:(BOOL)expanded;

+ (CGFloat)heightForEventRecord:(MTHTimeIntervalCustomEventRecord *)eventRecord
                       expanded:(BOOL)expanded;

@end

NS_ASSUME_NONNULL_END
