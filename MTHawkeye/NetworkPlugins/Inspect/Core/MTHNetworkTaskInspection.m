//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 24/08/2017
// Created by: EuanC
//


#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTransaction.h"

@interface MTHNetworkTaskInspection ()

@end


@implementation MTHNetworkTaskInspection

- (instancetype)init {
    if ((self = [super init])) {
        _enabled = YES;
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else if (![other isKindOfClass:[MTHNetworkTaskInspection class]]) {
        return NO;
    } else {
        MTHNetworkTaskInspection *otherInspection = (MTHNetworkTaskInspection *)other;
        return [self.name isEqualToString:otherInspection.name];
    }
}

- (NSUInteger)hash {
    return [self.name hash];
}

@end


@implementation MTHNetworkTaskInspectionParamEntity


@end
