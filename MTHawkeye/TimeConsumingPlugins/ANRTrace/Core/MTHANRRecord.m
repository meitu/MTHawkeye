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


#import "MTHANRRecord.h"


@implementation MTHANRRecordRaw

- (void)dealloc {
    if (self->stackframes) {
        free(self->stackframes);
        self->stackframes = nil;
    }
}

@end
