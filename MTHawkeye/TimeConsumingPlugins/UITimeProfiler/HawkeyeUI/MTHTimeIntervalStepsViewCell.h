//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/3
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHCallTraceTimeCostModel;
@class MTHTimeIntervalCustomEventRecord;

@interface MTHTimeIntervalStepsViewCellModel : NSObject

@property (nonatomic, assign) NSTimeInterval timeStamp;
@property (nonatomic, copy, nullable) NSString *timeStampTitle;

@property (nonatomic, strong, nullable) MTHCallTraceTimeCostModel *timeCostModel;
@property (nonatomic, strong, nullable) MTHTimeIntervalCustomEventRecord *customEvent;

@end


@interface MTHTimeIntervalStepsViewCell : UITableViewCell

@end

NS_ASSUME_NONNULL_END
