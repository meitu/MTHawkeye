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

@interface MTHANRRecordRaw : NSObject {
  @public
    uintptr_t titleFrame;
    uintptr_t *stackframes;
    size_t stackframesSize;
}

@property (nonatomic, assign) NSTimeInterval time;
@property (nonatomic, assign) float cpuUsed;

@end

@interface MTHANRRecord : NSObject

@property (nonatomic, strong) NSArray<MTHANRRecordRaw *> *rawRecords;
@property (nonatomic, assign) NSTimeInterval duration;

@end
