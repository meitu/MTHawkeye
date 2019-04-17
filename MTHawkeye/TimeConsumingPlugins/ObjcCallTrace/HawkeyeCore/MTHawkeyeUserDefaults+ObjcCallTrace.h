//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (ObjcCallTrace)

@property (nonatomic, assign) BOOL objcCallTraceOn;
@property (nonatomic, assign) CGFloat objcCallTraceTimeThresholdInMS;
@property (nonatomic, assign) NSInteger objcCallTraceDepthLimit;

@end

NS_ASSUME_NONNULL_END
