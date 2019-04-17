//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/10/16
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(mtha_set_last_allocation_event_name_t)(void *ptr, const char *classname);

extern mtha_set_last_allocation_event_name_t *mtha_allocation_event_logger;

@interface NSObject (MTHAllocTrack)

+ (void)mtha_startAllocTrack;
+ (void)mtha_endAllocTrack;

@end

NS_ASSUME_NONNULL_END
