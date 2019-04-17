//
//  SharedInstanceExample.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 03/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SharedInstanceExample : NSObject

+ (instancetype)shared;

+ (void)staticFuncWithParam:(id)obj;

@end
