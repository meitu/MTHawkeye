//
//  EnormousViewModel.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 16/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ANormalViewModel.h"

@interface EnormousViewModel : NSObject

@property (nonatomic, strong) NSMutableArray<EnormousViewModel *> *subModels;

- (void)createSubModelsWithCount:(NSInteger)count depth:(NSInteger)depth;

@end
