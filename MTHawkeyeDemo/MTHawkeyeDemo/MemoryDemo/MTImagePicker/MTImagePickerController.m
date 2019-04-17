//
//  MTImagePickerController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 10/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MTImagePickerController.h"
#import "MTPhotoAssetsViewController.h"

@interface MTImagePickerController ()

@property (nonatomic, strong) UINavigationController *inlineNavigationController;

@property (nonatomic, strong) NSMutableArray *list;

@end

@implementation MTImagePickerController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)setup {
    MTPhotoAssetsViewController *vc = [[MTPhotoAssetsViewController alloc] init];
    self.inlineNavigationController = [[UINavigationController alloc] initWithRootViewController:vc];
    //    self.inlineNavigationController.delegate = self;
    [self.inlineNavigationController willMoveToParentViewController:self];
    [self.inlineNavigationController.view setFrame:self.view.frame];
    [self.view addSubview:self.inlineNavigationController.view];
    [self addChildViewController:self.inlineNavigationController];
    [self.inlineNavigationController didMoveToParentViewController:self];

    self.list = [NSMutableArray array];
}

@end
