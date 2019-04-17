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


#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (LivingObjectsSniffer)

@property (nonatomic, assign) BOOL livingObjectsSnifferOn;

@property (nonatomic, assign) BOOL livingObjectsSnifferContainerSniffEnabled;

@property (nonatomic, assign) CGFloat livingObjectSnifferTaskDelayInSeconds;

@end

NS_ASSUME_NONNULL_END
