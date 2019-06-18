//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/20
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHawkeyePlugin.h"

NS_ASSUME_NONNULL_BEGIN

@class MTHANRRecord;

@interface MTHANRHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

+ (NSArray<MTHANRRecord *> *)readANRRecords;

@end

NS_ASSUME_NONNULL_END
