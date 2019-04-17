//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkObserver;

@interface MTHURLSessionDelegateProxy : NSObject <NSURLSessionDelegate>

- (instancetype)initWithOriginalDelegate:(nullable id)delegate observer:(MTHNetworkObserver *)observer;

@end

NS_ASSUME_NONNULL_END
