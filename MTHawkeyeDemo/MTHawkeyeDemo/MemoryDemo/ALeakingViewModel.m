//
//  ALeakingViewModel.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 10/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "ALeakingViewModel.h"
#import <UIKit/UIKit.h>

@protocol ALeakingViewModelDelegate <NSObject>

@end


@interface ALeakingViewModel () <ALeakingViewModelDelegate>

@property (copy, nonatomic) NSString *testString;
@property (retain, nonatomic) id<ALeakingViewModelDelegate> delegate;

@end


@implementation ALeakingViewModel

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    // Warning, Memory Leak: retain cycle.
    self.delegate = self;

    //    __weak typeof(self) weak_self = self;
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    // Warning, Memory Leak: should be weak_self
                    self.testString = @"";
                }];
}

@end


@implementation AViewModelWithLeakingProperty

- (instancetype)init {
    if (self = [super init]) {
        self.viewModelWillLeak = [[ALeakingViewModel alloc] init];
    }
    return self;
}

@end

@interface MBCCameraCapturingConfiguration ()

@property (copy, nonatomic) NSString *aString;

@end

@implementation MBCCameraCapturingConfiguration

@synthesize aaaaaa;
@synthesize aString = aStringNewName;

@end
