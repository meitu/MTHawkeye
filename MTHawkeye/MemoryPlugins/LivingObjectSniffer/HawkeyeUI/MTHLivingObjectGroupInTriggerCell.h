//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/14
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHLivingObjectGroupInTrigger;
@interface MTHLivingObjectGroupInTriggerCell : UITableViewCell

- (void)configureWithLivingInstancesGroup:(MTHLivingObjectGroupInTrigger *)group;

+ (CGFloat)cellHeight;

@end

NS_ASSUME_NONNULL_END
