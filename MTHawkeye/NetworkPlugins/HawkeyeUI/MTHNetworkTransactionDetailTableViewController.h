//
// Copyright (c) 2014-2016, Flipboard
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2/10/15
// Created by: Ryan Olson
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTransaction;
@class MTHNetworkTaskAdvice;

@interface MTHNetworkTransactionDetailTableViewController : UITableViewController

@property (nonatomic, strong) MTHNetworkTransaction *transaction;
@property (nonatomic, strong, nullable) NSArray<MTHNetworkTaskAdvice *> *advices;

@end

NS_ASSUME_NONNULL_END
