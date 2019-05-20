//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 08/09/2017
// Created by: EuanC
//


#import "MTHNetworkTaskInspectResultsViewController.h"
#import "MTHNetworkHawkeyeUI.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkRecordsStorage.h"
#import "MTHNetworkTaskInspectAdvicesViewController.h"
#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"

#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/MTHawkeyeSettingViewController.h>
#import <MTHawkeye/UITableView+MTHEmptyTips.h>
#import <MTHawkeye/UIViewController+MTHawkeyeLayoutSupport.h>


@interface MTHNetworkTaskInspectResultsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MTHNetworkTaskInspectResults *inspectResults;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *advicesDict;

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *transactions; /**< 在页面销毁前，强引用 transaction */

@end


@implementation MTHNetworkTaskInspectResultsViewController

- (instancetype)init {
    if ((self = [super init])) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsZero;
    self.view = self.tableView;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"network-inspection-advice-cell"];
}

- (void)inspectIfNeeded {
    if (![MTHNetworkTaskInspector isEnabled])
        return;

    [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Loading ..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        self.transactions = [[MTHNetworkRecordsStorage shared] readNetworkTransactions];

        [[MTHNetworkTaskInspector shared]
            inspectTransactions:self.transactions
              completionHandler:^(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *_Nonnull advicesDict) {
                  self.advicesDict = advicesDict;
                  self.inspectResults = [MTHNetworkTaskInspector shared].inspectResults;

                  [self updateTableViewFooter];
              }];
    });
}

- (void)updateTableViewFooter {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if (![MTHNetworkTaskInspector isEnabled]) {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Network Inspect Off" tipsTop:80.f button:@"Go to Setting" btnTarget:self btnAction:@selector(gotoSetting)];
        } else {
            if (self.inspectResults.groups.count > 0) {
                [self.tableView mthawkeye_removeEmptyTipsFooterView];
            } else {
                [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Empty inspect result"];
            }
        }
        [self.tableView reloadData];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateTableViewFooter];
    [self inspectIfNeeded];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
    } else {
        UIEdgeInsets insets = UIEdgeInsetsMake([self mt_hawkeye_navigationBarTopLayoutGuide].length, 0, 0, 0);
        if (fabs(insets.top - self.tableView.contentInset.top) < DBL_EPSILON) {
            self.tableView.contentInset = insets;
            self.tableView.scrollIndicatorInsets = insets;
            self.tableView.contentOffset = CGPointMake(0, -insets.top);
        }
    }
#endif
}


#pragma mark - UITableViewDatasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.inspectResults.groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < self.inspectResults.groups.count) {
        return self.inspectResults.groups[section].inspections.count;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < self.inspectResults.groups.count) {
        return self.inspectResults.groups[section].name;
    } else {
        return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"network-inspection-advice-cell" forIndexPath:indexPath];
    cell.textLabel.font = [UIFont systemFontOfSize:14];

    if (indexPath.section < self.inspectResults.groups.count) {
        MTHNetworkTaskInspectionsGroup *group = self.inspectResults.groups[indexPath.section];
        if (indexPath.row < group.inspections.count) {
            MTHNetworkTaskInspectionWithResult *inspectionWithResult = group.inspections[indexPath.row];
            NSMutableString *info = [NSMutableString string];
            if (inspectionWithResult.advices.count > 0) {
                [info appendFormat:@"[%@] ", @(inspectionWithResult.advices.count)];
                cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.3 alpha:1.f];
            } else {
                cell.textLabel.textColor = [UIColor colorWithWhite:.6 alpha:1.f];
            }
            [info appendString:inspectionWithResult.inspection.displayName];

            cell.textLabel.text = info;
            cell.accessoryType = (inspectionWithResult.advices.count > 0) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section < self.inspectResults.groups.count) {
        MTHNetworkTaskInspectionsGroup *group = self.inspectResults.groups[indexPath.section];
        if (indexPath.row < group.inspections.count) {
            MTHNetworkTaskInspectionWithResult *inspectionWithResult = group.inspections[indexPath.row];
            if (inspectionWithResult.advices.count > 0) {
                MTHNetworkTaskInspectAdvicesViewController *vc = [[MTHNetworkTaskInspectAdvicesViewController alloc]
                    initWithTaskInspectionResult:inspectionWithResult
                          advicesForTransactions:self.advicesDict];
                [self.navigationController pushViewController:vc animated:YES];
            }
        }
    }
}

// MARK: -
- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *setEntity = [[MTHawkeyeSettingTableEntity alloc] init];
    setEntity.sections = @[ [MTHNetworkHawkeyeSettingUI networkInspecSection] ];
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Network Inspect" viewModelEntity:setEntity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
