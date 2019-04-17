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


#import <objc/message.h>
#import <objc/runtime.h>
#import "MTH_RSSwizzle.h"
#import "NSObject+MTHAllocTrack.h"


#if __has_feature(objc_arc)
#error This file must be compiled without ARC. Use -fno-objc-arc flag.
#endif

mtha_set_last_allocation_event_name_t *mtha_allocation_event_logger = NULL;

static BOOL mtha_isAllocTracking = NO;

@implementation NSObject (MTHAllocTrack)

+ (void)mtha_startAllocTrack {
    if (!mtha_isAllocTracking) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            mtha_isAllocTracking = YES;

            SEL allocSEL = @selector(alloc);

            id (^allocImpFactory)(MTH_RSSwizzleInfo *swizzleInfo) = ^id(MTH_RSSwizzleInfo *swizzleInfo) {
                return Block_copy(^id(__unsafe_unretained id self) {
                    id (*originalIMP)(__unsafe_unretained id, SEL);
                    originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
                    id obj = originalIMP(self, allocSEL);

                    if (mtha_isAllocTracking && mtha_allocation_event_logger) {
                        mtha_allocation_event_logger(obj, class_getName([obj class]));
                    }

                    return obj;
                });
            };
            [MTH_RSSwizzle swizzleClassMethod:allocSEL inClass:NSObject.class newImpFactory:allocImpFactory];
        });
    }
}

+ (void)mtha_endAllocTrack {
    mtha_isAllocTracking = NO;
}

@end
