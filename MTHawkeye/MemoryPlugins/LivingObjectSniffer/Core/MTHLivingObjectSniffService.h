//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/6
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHLivingObjectSniffer.h"

NS_ASSUME_NONNULL_BEGIN


@interface MTHLivingObjectSniffService : NSObject
@property (nonatomic, readonly) MTHLivingObjectSniffer *sniffer;
@property (nonatomic, assign) NSTimeInterval delaySniffInSeconds; // default 3.f

+ (instancetype)shared;

- (void)start;
- (void)stop;
- (BOOL)isRunning;

- (void)addIgnoreList:(NSArray<NSString *> *)ignoreList;

@end


NS_ASSUME_NONNULL_END
