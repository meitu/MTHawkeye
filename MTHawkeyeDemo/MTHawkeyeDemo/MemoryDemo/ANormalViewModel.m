//
//  ANormalViewModel.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 04/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "ANormalViewModel.h"

@implementation ANormalViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _classProperty = self.class;
    }
    return self;
}

@end
