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


#import "MTHNetworkTaskAdvice.h"

@implementation MTHNetworkTaskAdvice

- (NSString *)description {
    NSString *desc = [NSString stringWithFormat:@"index:(%@), type: %@,  title: %@, \n  desc: %@, \n  suggest: %@", @(self.requestIndex), self.typeId, self.adviceTitleText, self.adviceDescText, self.suggestDescText];
    if (self.userInfo) {
        desc = [desc stringByAppendingFormat:@", \n userinfo: %@", self.userInfo];
    }
    return desc;
}

- (NSString *)levelText {
    switch (self.level) {
        case MTHNetworkTaskAdviceLevelHigh:
            return @"High";
        case MTHNetworkTaskAdviceLevelMiddle:
            return @"Warning";
        case MTHNetworkTaskAdviceLevelLow:
            return @"Optimization";
    }
    return @"";
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@", @(self.requestIndex), self.typeId] hash];
}

- (BOOL)isEqual:(MTHNetworkTaskAdvice *)object {
    if (self.requestIndex != object.requestIndex) {
        return NO;
    }

    if (![self.typeId isEqualToString:object.typeId]) {
        return NO;
    }

    return YES;
}

@end
