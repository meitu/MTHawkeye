//
//  AlertRetainedViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 11/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "AlertRetainedViewController.h"

@interface AlertRetainedViewController ()

@property (nonatomic, copy) NSString *testText;

@end

@implementation AlertRetainedViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(20, 100, 60, 20)];
    [btn addTarget:self action:@selector(showAlert) forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:@"Alert" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [btn sizeToFit];
    [self.view addSubview:btn];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showAlert {
    //    __weak typeof(self) weak_self = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"alert" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_Nonnull action) {
                                                // Warning, Memory Leak: should use weak_self (Xcode 8)
                                                self.testText = @"test";
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
