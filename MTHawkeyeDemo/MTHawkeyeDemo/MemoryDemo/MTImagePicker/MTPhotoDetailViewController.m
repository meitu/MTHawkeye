//
//  MTPhotoDetailViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 10/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MTPhotoDetailViewController.h"
#import "ALeakingViewModel.h"

@protocol MTPhotoDetailViewControllerDelegate1 <NSObject>

@end


@interface MTPhotoDetailViewController () <MTPhotoDetailViewControllerDelegate1>

@property (strong, nonatomic) ALeakingViewModel *leakingViewModel;
@property (strong, nonatomic) id<MTPhotoDetailViewControllerDelegate1> strongDelegate;

@end

@implementation MTPhotoDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor lightGrayColor];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MTPhotoDetailViewController-Property-Leak-Mock"]) {
        self.leakingViewModel = [[ALeakingViewModel alloc] init];
        self.strongDelegate = self;
    }

    // 开启监测时，如果此处有访问 presentationController，会造成内存泄露误报
    //    if (self.presentationController == nil) {
    //        NSLog(@" ---> %@", self.presentationController);
    //    }
}

@end
