//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

@class MTHANRTrace;

@interface MTHANRRecordsViewController : UIViewController

- (instancetype)initWithANRMonitor:(MTHANRTrace *)anrMonitor;

@end
