//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 01/11/2017
// Created by: EuanC
//


#import "MTHCallTraceTimeCostModel.h"

@implementation MTHCallTraceTimeCostModel

- (NSString *)description {
    NSMutableString *str = [NSMutableString new];
    [str appendFormat:@"%2d| ", (int)_callDepth];
    [str appendFormat:@"%-8sms|", [[NSString stringWithFormat:@"%6.2f", _timeCostInMS] UTF8String]];
    for (NSUInteger i = 0; i < _callDepth; i++) {
        [str appendString:@"  "];
    }
    [str appendFormat:@"%s[%@ %@]", (_isClassMethod ? "+" : "-"), _className, _methodName];

    for (MTHCallTraceTimeCostModel *item in _subCosts) {
        [str appendFormat:@"\r%@", item];
    }

    return [str copy];
}

@end
