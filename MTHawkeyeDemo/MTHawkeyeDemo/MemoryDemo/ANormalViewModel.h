//
//  ANormalViewModel.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 04/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ANormalViewModel : NSObject

@property (nonatomic, strong) Class classProperty; /**< Class property, ivar type: #, lead to a crash of object_getIvar() */

@end
