//
//  MemoryPerformanceTestViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 16/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MemoryPerformanceTestViewController.h"
#import <MTHawkeye/UIDevice+MTHLivingObjectSniffer.h>
#import "EnormousViewModel.h"

@interface MemoryPerformanceTestViewController ()

@property (nonatomic, strong) EnormousViewModel *viewModel;

@property (nonatomic, strong) UILabel *memoryUsedLabel1;
@property (nonatomic, strong) UILabel *memoryUsedLabel2;
@property (nonatomic, strong) UILabel *memoryUsedLabel3;

@property (nonatomic, strong) UIButton *refreshMemoryUsedBtn;
@property (nonatomic, strong) UIButton *releaseViewModelBtn;
@property (nonatomic, strong) UIButton *releaseViewsBtn;

@property (nonatomic, strong) dispatch_source_t statUpdateTimer;

@end

@implementation MemoryPerformanceTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    self.memoryUsedLabel1 = [[UILabel alloc] initWithFrame:CGRectMake(15, 100, 120, 20)];
    self.memoryUsedLabel1.textColor = [UIColor blackColor];
    self.memoryUsedLabel1.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:self.memoryUsedLabel1];

    self.memoryUsedLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(15, 125, 120, 20)];
    self.memoryUsedLabel2.textColor = [UIColor blackColor];
    self.memoryUsedLabel2.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:self.memoryUsedLabel2];

    self.memoryUsedLabel3 = [[UILabel alloc] initWithFrame:CGRectMake(15, 150, 120, 20)];
    self.memoryUsedLabel3.textColor = [UIColor blackColor];
    self.memoryUsedLabel3.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:self.memoryUsedLabel3];

    CGFloat x = self.view.bounds.size.width - 150;
    self.releaseViewModelBtn = [[UIButton alloc] initWithFrame:CGRectMake(x, 100, 130, 30)];
    [self.releaseViewModelBtn setTitle:@"Release ViewModels" forState:UIControlStateNormal];
    [self.releaseViewModelBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.releaseViewModelBtn addTarget:self action:@selector(releaseBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.releaseViewModelBtn];

    self.viewModel = [[EnormousViewModel alloc] init];
    [self.viewModel createSubModelsWithCount:10 depth:4];


    /*
     MemoryUsed:
     1. after create viewModel & views.   a
     2. after MTMemoryDebugger observe.   b
     3. after release viewModel & views.  c
     */
}

- (void)viewDidAppear:(BOOL)animated {
    self.memoryUsedLabel1.text = [self currentMemoryUsed];

    [super viewDidAppear:animated];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.memoryUsedLabel2.text = [self currentMemoryUsed];
        });
    });
}

- (void)releaseBtnTapped {
    self.viewModel = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.memoryUsedLabel3.text = [self currentMemoryUsed];
        });
    });
}

- (NSString *)currentMemoryUsed {
    CGFloat memoryAppUsedInMB = [UIDevice currentDevice].memoryAppUsed / 1024.f / 1024.f;
    NSLog(@"mem: %lld bytes  %f MB", [UIDevice currentDevice].memoryAppUsed, memoryAppUsedInMB);
    return [NSString stringWithFormat:@"%f MB", memoryAppUsedInMB];
}

@end
