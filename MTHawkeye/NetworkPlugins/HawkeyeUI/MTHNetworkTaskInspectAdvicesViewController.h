//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 09/09/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTaskInspectionWithResult;
@class MTHNetworkTaskAdvice;

@interface MTHNetworkTaskInspectAdvicesViewController : UITableViewController

- (instancetype)initWithTaskInspectionResult:(MTHNetworkTaskInspectionWithResult *)inspectionResult
                      advicesForTransactions:(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *)advicesDict;

@end

NS_ASSUME_NONNULL_END
