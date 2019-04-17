//
//  SharedInstanceExample.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 03/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "SharedInstanceExample.h"

@implementation SharedInstanceExample

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)staticFuncWithParam:(id)obj {
}

@end
