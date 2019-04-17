//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/4/11
// Created by: David.Dai
//


#import "NSArray+MTHLivingObjectSniffer.h"
#import "NSObject+MTHLivingObjectSniffer.h"

@implementation NSArray (MTHLivingObjectSniffer)

// MARK: - MTHLivingObjectShadowing
- (MTHLivingObjectShadow *)mth_castShadowFromLight:(nullable id)light {
    return [super mth_castShadowFromLight:light];
}

- (void)mth_castShadowOver:(MTHLivingObjectShadowPackage *)shadowPackage withLight:(nullable id)light {
    if (mthawkeye_livingObjectsSnifferNSFoundationContainerEnabled) {
        [self enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj conformsToProtocol:@protocol(MTHLivingObjectShadowing)]) {
                [(id<MTHLivingObjectShadowing>)obj mth_castShadowOver:shadowPackage withLight:light];
            }
        }];
    }

    [super mth_castShadowOver:shadowPackage withLight:light];
}

- (BOOL)mth_shouldObjectAlive {
    return [super mth_shouldObjectAlive];
}

@end
