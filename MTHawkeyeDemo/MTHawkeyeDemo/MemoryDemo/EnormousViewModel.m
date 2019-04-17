//
//  EnormousViewModel.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 16/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "EnormousViewModel.h"

@implementation EnormousViewModel

- (void)createSubModelsWithCount:(NSInteger)count depth:(NSInteger)depth {
    NSMutableArray *list = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < count; i++) {
        EnormousViewModel *svm = [[EnormousViewModel alloc] init];
        if (depth - 1 > 0) {
            [svm createSubModelsWithCount:count depth:depth - 1];
        }
        [list addObject:svm];
    }
    self.subModels = list;
}

@end
