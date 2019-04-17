//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHLivingObjectInfo.h"
#import "MTHawkeyePlugin.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHLivingObjectsWarningProtocol;

@interface MTHLivingObjectsSnifferHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

@property (nonatomic, weak, nullable) id<MTHLivingObjectsWarningProtocol> delegate;

@end


@protocol MTHLivingObjectsWarningProtocol <NSObject>

- (void)sniffOutUnexpectLivingObject:(MTHLivingObjectInfo *)objInfo extraInfo:(MTHLivingObjectGroupInClass *)group;

@end

NS_ASSUME_NONNULL_END
