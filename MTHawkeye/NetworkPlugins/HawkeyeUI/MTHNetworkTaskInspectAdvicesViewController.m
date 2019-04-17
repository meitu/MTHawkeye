//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 09/09/2017
// Created by: EuanC
//


#import "MTHNetworkTaskInspectAdvicesViewController.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "MTHNetworkTransactionAdviceDetailViewController.h"
#import "MTHNetworkTransactionDetailTableViewController.h"
#import "MTHPopoverViewController.h"


@interface MTHNetworkTaskInspectAdvicesViewController ()

@property (nonatomic, strong) MTHNetworkTaskInspectionWithResult *inspectionWithResult;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *advicesDict;

@end


@implementation MTHNetworkTaskInspectAdvicesViewController

- (instancetype)initWithTaskInspectionResult:(MTHNetworkTaskInspectionWithResult *)inspectionResult
                      advicesForTransactions:(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *)advicesDict {
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        _inspectionWithResult = inspectionResult;
        _advicesDict = advicesDict;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.inspectionWithResult.inspection.displayName;
}

#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.inspectionWithResult.advices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hawkeye-network-inspect-with-advice-cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"hawkeye-network-inspect-with-advice-cell"];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    }

    MTHNetworkTaskAdvice *advice = self.inspectionWithResult.advices[indexPath.row];
    MTHNetworkTransaction *transaction = [self transactionFromAdvice:advice];
    NSString *pathText = [self pathTextForTransaction:transaction];
    NSString *nameText = [self nameTextForTransaction:transaction];
    NSString *titleText = [NSString stringWithFormat:@"%@: %@, %@", @(transaction.requestIndex), pathText, nameText];
    cell.detailTextLabel.text = titleText;
    cell.textLabel.text = advice.adviceTitleText;

    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    MTHNetworkTaskAdvice *advice = self.inspectionWithResult.advices[indexPath.row];
    MTHNetworkTransactionAdviceDetailViewController *vc = [[MTHNetworkTransactionAdviceDetailViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.advice = advice;

    [self presentViewControllerInPopover:vc];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    MTHNetworkTaskAdvice *advice = self.inspectionWithResult.advices[indexPath.row];
    MTHNetworkTransaction *transaction = [self transactionFromAdvice:advice];

    MTHNetworkTransactionDetailTableViewController *vc = [[MTHNetworkTransactionDetailTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.transaction = transaction;

    NSString *key = [NSString stringWithFormat:@"%@", @(transaction.requestIndex)];
    NSArray<MTHNetworkTaskAdvice *> *advices = self.advicesDict[key];
    vc.advices = advices;
    [self.navigationController pushViewController:vc animated:YES];
}

// MARK:

- (void)presentViewControllerInPopover:(UIViewController *)viewController {
    MTHPopoverViewController *popoverVC = [[MTHPopoverViewController alloc] initWithContentViewController:viewController fromSourceView:self.view];
    // use system style.
    [popoverVC.navigationBar setBarTintColor:nil];
    [popoverVC.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [popoverVC.navigationBar setShadowImage:nil];
    [popoverVC.navigationBar setTitleTextAttributes:nil];
    [self presentViewController:popoverVC animated:YES completion:nil];
}

// MAKR: -

- (MTHNetworkTransaction *)transactionFromAdvice:(MTHNetworkTaskAdvice *)advice {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:advice.requestIndex];
    return [[[MTHNetworkTaskInspector shared].context transactionsForRequestIndexes:indexSet] firstObject];
}

- (NSString *)nameTextForTransaction:(MTHNetworkTransaction *)transaction {
    NSURL *url = transaction.request.URL;
    NSString *name = [url lastPathComponent];
    if ([name length] == 0) {
        name = @"/";
    }
    return name;
}

- (NSString *)pathTextForTransaction:(MTHNetworkTransaction *)transaction {
    NSURL *url = transaction.request.URL;
    NSMutableArray *mutablePathComponents = [[url pathComponents] mutableCopy];
    if ([mutablePathComponents count] > 0) {
        [mutablePathComponents removeLastObject];
    }
    NSString *path = [url host];
    for (NSString *pathComponent in mutablePathComponents) {
        path = [path stringByAppendingPathComponent:pathComponent];
    }
    return path;
}

@end
