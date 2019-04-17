//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 29/06/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHLivingObjectShadow.h"

@interface NSObject (MTHLivingObjectSniffer) <MTHLivingObjectShadowing>

@property (strong, nonatomic) MTHLivingObjectShadow *mth_livingObjectShadow;

@end
