//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 18/07/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHNetworkTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHNetworkWaterfallViewCellModel : NSObject

@property (nonatomic, assign) NSTimeInterval timelineStartAt;  // timeline 起始时间
@property (nonatomic, assign) NSTimeInterval timelineDuration; // timeline 总的时间区间

@property (nonatomic, strong) MTHNetworkTransaction *transaction;        // 当前 cell 要展示的请求记录
@property (nonatomic, strong) MTHNetworkTransaction *focusedTransaction; // 当前 timeline 选中的请求记录，可能有交叉

@end

NS_ASSUME_NONNULL_END
