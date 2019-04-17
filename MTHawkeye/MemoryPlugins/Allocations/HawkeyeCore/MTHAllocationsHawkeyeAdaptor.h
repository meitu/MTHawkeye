//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/17
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHawkeyePlugin.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHAllocationsHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

+ (void)startAllocationsTracer;
+ (void)stopAllocationsTracer;
+ (void)startSingleChunkMallocTracer;
+ (void)stopSingleChunkMallocTracer;

@end

NS_ASSUME_NONNULL_END
