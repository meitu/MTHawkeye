//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/06/2018
// Created by: Huni
//


#import "MTHToastViewMaker.h"

@implementation MTHToastViewMaker

- (NSString *)title {
    if (!_title) {
        _title = @"";
    }
    return _title;
}

- (NSString *)shortContent {
    if (!_shortContent) {
        _shortContent = @"";
    }
    return _shortContent;
}

- (NSString *)longContent {
    if (!_longContent) {
        _longContent = @"";
    }
    return _longContent;
}

- (NSTimeInterval)stayDuration {
    if (!_stayDuration) {
        _stayDuration = 1.5;
    }
    return _stayDuration;
}

@end
