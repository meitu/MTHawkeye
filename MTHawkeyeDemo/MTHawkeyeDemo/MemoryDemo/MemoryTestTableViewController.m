//
//  SecondTableViewController.m
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import "MemoryTestTableViewController.h"
#import "ALeakingViewController.h"
#import "ANormalViewModel.h"
#import "AlertRetainedViewController.h"
#import "FacebookProjectsTableViewController.h"
#import "MTImagePickerController.h"
#import "MemoryPerformanceTestViewController.h"
#import "ReusePropertyTestViewController.h"


@interface MemoryTestTableViewController ()

@property (strong, nonatomic) MemoryTestTableViewController *willLeakViewController;

@property (strong, nonatomic) ANormalViewModel *viewModel;
@property (strong, nonatomic) ANormalViewModel *sharedViewModel;
@property (strong, nonatomic) ANormalViewModel *existViewModel;

@end

@implementation MemoryTestTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.existViewModel = [[ANormalViewModel alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            ALeakingViewController *vc = [[ALeakingViewController alloc] init];
            UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:nv animated:YES completion:nil];
        } else if (indexPath.row == 1) {
            self.willLeakViewController = [[MemoryTestTableViewController alloc] init];
            [self.navigationController pushViewController:self.willLeakViewController animated:YES];
        } else if (indexPath.row == 2) {
            // 测试通过非常规方式打开的 viewController 不会误报为内存泄露
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MTPhotoDetailViewController-Property-Leak-Mock"];
            MTImagePickerController *vc = [[MTImagePickerController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 3) {
            // 测试通过非常规方式打开的 viewController 如果有包含循环引用。 应该报内存泄露
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MTPhotoDetailViewController-Property-Leak-Mock"];
            MTImagePickerController *vc = [[MTImagePickerController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 5) {
            ReusePropertyTestViewController *vc = [[ReusePropertyTestViewController alloc] init];

            // 临时创建 viewModel, 需要等到这个控制器释放或重新创建时才会释放
            self.viewModel = [[ANormalViewModel alloc] init];
            vc.viewModel = self.viewModel;

            // 临时创建 viewModel，需要等到这个控制器释放才会释放
            if (self.sharedViewModel == nil) {
                self.sharedViewModel = [[ANormalViewModel alloc] init];
            }
            vc.sharedViewModel = self.sharedViewModel;

            // 本控制器创建的 viewModel，在本控制器开始时就开始监听，进入下一级后标记为被重用
            vc.existMainViewModel = self.existViewModel;

            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 6) {
            AlertRetainedViewController *vc = [[AlertRetainedViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else if (indexPath.section == 1) {
        FacebookProjectsTableViewController *vc = [[FacebookProjectsTableViewController alloc] initWithStyle:UITableViewStylePlain];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.section == 2) {
        MemoryPerformanceTestViewController *vc = [[MemoryPerformanceTestViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
