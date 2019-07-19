//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/09/2017
// Created by: EuanC
//

#import <Foundation/Foundation.h>

@interface MTHANRMainThreadStallingSnapshot : NSObject {
  @public
    uintptr_t titleFrame;
    uintptr_t *stackframes;
    size_t stackframesSize;
}

@property (nonatomic, assign) NSTimeInterval time;
@property (nonatomic, assign) float cpuUsed;
@property (nonatomic, assign) NSInteger capturedCount;
@property (nonatomic, assign) BOOL isInBackground;
@property (nonatomic, assign) NSInteger totalThreadCount;

@end

@interface MTHANRRecord : NSObject

@property (nonatomic, strong) NSArray<MTHANRMainThreadStallingSnapshot *> *stallingSnapshots;
@property (nonatomic, assign) NSTimeInterval startFrom;
@property (nonatomic, assign) NSTimeInterval durationInSeconds;
@property (nonatomic, assign) BOOL isInBackground;

@end
