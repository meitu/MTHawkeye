//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MTNetworkHistoryViewCellIdentifier;

typedef NS_ENUM(NSInteger, MTHNetworkHistoryViewCellStatus) {
    MTHNetworkHistoryViewCellStatusDefault = 0,     // 普通状态
    MTHNetworkHistoryViewCellStatusOnFocus = 1,     // 当前焦点所在请求记录cell
    MTHNetworkHistoryViewCellStatusOnWaterfall = 2, // 当前在 waterfall 视图可见的请求对应的请求记录 cell
};

@class MTHNetworkTransaction;
@class MTHNetworkTaskAdvice;
@protocol MTHNetworkHistoryViewCellDelegate;

@interface MTHNetworkHistoryViewCell : UITableViewCell

@property (nonatomic, strong) MTHNetworkTransaction *transaction;
@property (nonatomic, strong, nullable) NSArray<MTHNetworkTaskAdvice *> *advices;
@property (nonatomic, weak, nullable) id<MTHNetworkHistoryViewCellDelegate> delegate;

@property (nonatomic, assign) MTHNetworkHistoryViewCellStatus status;

@property (nonatomic, copy, nullable) NSSet<NSString *> *warningAdviceTypeIDs;

+ (CGFloat)preferredCellHeight;

@end


@protocol MTHNetworkHistoryViewCellDelegate <NSObject>

- (void)mt_networkHistoryViewCellDidTappedDetail:(MTHNetworkHistoryViewCell *)cell;

@end

NS_ASSUME_NONNULL_END
