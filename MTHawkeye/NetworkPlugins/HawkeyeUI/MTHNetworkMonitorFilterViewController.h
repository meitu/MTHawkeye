//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/8
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>
#import "MTHNetworkTransactionsURLFilter.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHNetworkMonitorFilterDelegate <NSObject>

- (void)filterUpdatedWithStatusCodes:(MTHNetworkTransactionStatusCode)statusCodes inspections:(nullable NSArray *)inspections hosts:(nullable NSArray *)hosts;

@end

@interface MTHNetworkMonitorFilterViewController : UITableViewController

@property (nonatomic, weak) id<MTHNetworkMonitorFilterDelegate> filterDelegate;

@end

NS_ASSUME_NONNULL_END
