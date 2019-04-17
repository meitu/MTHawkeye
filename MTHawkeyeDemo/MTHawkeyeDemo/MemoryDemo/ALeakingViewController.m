//
//  ALeakingViewController.m
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import "ALeakingViewController.h"
#import "ALeakingViewModel.h"

#import <MTHawkeye/MTHawkeyeUserDefaults.h>

@interface ALeakingViewController ()

@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) ALeakingViewModel *viewModel;


@end

@implementation ALeakingViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor grayColor];

    // Warning, Memory Leak:
    self.timer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(test) userInfo:nil repeats:true];

    UIButton *btn = [UIButton new];
    [btn setTitle:@"Close" forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor blackColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.frame = CGRectMake(self.view.frame.size.width / 2 - 100 / 2, 200, 100, 50);
    [btn addTarget:self
                  action:@selector(btnCloseClick)
        forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];

    self.viewModel = [[ALeakingViewModel alloc] init];
}

- (void)test {
    NSLog(@"timer is still alive");
}

- (void)btnCloseClick {
    [self dismissViewControllerAnimated:true
                             completion:^{
                             }];
}

@end
