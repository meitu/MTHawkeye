//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 11/06/2018
// Created by: Huni
//


#import <objc/runtime.h>
#import "UIButton+MTHBlocks.h"

static char overviewKey;

@implementation UIButton (MTHBlocks)

- (void)mth_handleControlEvent:(UIControlEvents)event withBlock:(MTHToastButtonActionBlock)block {
    objc_setAssociatedObject(self, &overviewKey, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:@selector(mth_callActionBlock:) forControlEvents:event];
}


- (void)mth_callActionBlock:(id)sender {
    MTHToastButtonActionBlock block = (MTHToastButtonActionBlock)objc_getAssociatedObject(self, &overviewKey);
    if (block) {
        block();
    }
}

@end
