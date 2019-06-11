//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/11/2017
// Created by: EuanC
//


#import "MTHUITimeProfilerResultViewController.h"
#import "MTHCallTrace.h"
#import "MTHCallTraceTimeCostModel.h"
#import "MTHPopoverViewController.h"
#import "MTHTimeIntervalRecorder.h"
#import "MTHTimeIntervalStepsViewController.h"
#import "MTHUITImeProfilerResultEventCell.h"
#import "MTHUITimeProfilerHawkeyeAdaptor.h"
#import "MTHUITimeProfilerHawkeyeUI.h"
#import "MTHUITimeProfilerResultCallTraceCell.h"
#import "MTHUITimeProfilerResultSectionHeaderView.h"
#import "MTHUITimeProfilerResultViewModel.h"

#import "MTHawkeyeUserDefaults+ObjcCallTrace.h"
#import "MTHawkeyeUserDefaults+UITimeProfiler.h"

#import <MTHawkeye/MTHawkeyeSettingViewController.h>
#import <MTHawkeye/UITableView+MTHEmptyTips.h>
#import <MTHawkeye/UIViewController+MTHawkeyeLayoutSupport.h>


static NSString *const kMTHCallTraceIsNeedAlertKey = @"com.meitu.hawkeye.calltrace.alert";


@interface MTHUITimeProfilerResultViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) MTHUITimeProfilerResultViewModel *viewModel;

@end


@implementation MTHUITimeProfilerResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"UI Time Profiler";

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsZero;
    self.tableView.sectionHeaderHeight = 40.f;
    [self.tableView registerClass:[MTHUITimeProfilerResultCallTraceCell class] forCellReuseIdentifier:NSStringFromClass([MTHUITimeProfilerResultCallTraceCell class])];
    [self.tableView registerClass:[MTHUITImeProfilerResultEventCell class] forCellReuseIdentifier:NSStringFromClass([MTHUITImeProfilerResultEventCell class])];
    [self.tableView registerClass:[MTHUITimeProfilerResultSectionHeaderView class] forHeaderFooterViewReuseIdentifier:NSStringFromClass([MTHUITimeProfilerResultSectionHeaderView class])];
    self.view = self.tableView;

    BOOL isEnable = [MTHCallTrace isRunning];
    if (isEnable)
        [MTHCallTrace disable];

    [self setupViewModel];

    if (isEnable)
        [MTHCallTrace enable];

    [self updateTableView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL isEnable = [MTHCallTrace isRunning];
    BOOL isAlert = [[NSUserDefaults standardUserDefaults] boolForKey:kMTHCallTraceIsNeedAlertKey];
    if (!isEnable && !isAlert) {
        __weak typeof(self) weakSelf = self;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"You can use 'ObjC Call Trace' to simply find out time-consuming main thread Objective-C methods" message:@"" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Go to Setting"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
                                                    [weakSelf gotoSetting];
                                                }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMTHCallTraceIsNeedAlertKey];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateTableView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
    } else {
        UIEdgeInsets insets = UIEdgeInsetsMake([self mt_hawkeye_navigationBarTopLayoutGuide].length, 0, 0, 0);
        if (fabs(insets.top - self.tableView.contentInset.top) > DBL_EPSILON) {
            self.tableView.contentInset = insets;
            self.tableView.scrollIndicatorInsets = insets;
            self.tableView.contentOffset = CGPointMake(0, -insets.top);
        }
    }
#endif
}

- (void)updateTableView {
    MTHawkeyeUserDefaults *defaults = [MTHawkeyeUserDefaults shared];
    if (!defaults.vcLifeTraceOn || !defaults.objcCallTraceOn) {
        NSString *tips;
        if (defaults.vcLifeTraceOn) {
            tips = @"Objective-C call tracing is OFF\n"
                   @"Go turn on 'Trace ObjC Call', then relaunch";
        } else if (defaults.objcCallTraceOn) {
            tips = @"ViewController life tracing profiler is OFF\n"
                   @"Go turn on 'Trace VC Life', then relaunch";
        } else {
            tips = @"UI time profiler is OFF\n"
                   @"Turn on 'Trace VC Life' & 'Trace ObjC Call'\n"
                   @"Then relaunch";
        }
        [self.tableView mthawkeye_setFooterViewWithEmptyTips:tips
                                                     tipsTop:45.f
                                                      button:@"Go to Setting"
                                                   btnTarget:self
                                                   btnAction:@selector(gotoSetting)];
    } else {
        NSString *tips = [NSString stringWithFormat:@"ObjC call trace threshold: %@ms", @([MTHCallTrace currentTraceTimeThreshold])];
        [self.tableView mthawkeye_setFooterViewWithEmptyTips:tips];
    }

    [self.tableView reloadData];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(rightBarItemAction)];
}

- (void)setupViewModel {
    NSArray<MTHViewControllerAppearRecord *> *vcAppearedRecords = [MTHUITimeProfilerHawkeyeAdaptor readViewControllerAppearedRecords];
    NSArray<MTHCallTraceTimeCostModel *> *calltraceRecords = [MTHCallTrace prettyRecords];
    NSArray<MTHTimeIntervalCustomEventRecord *> *customEventsRecords = [MTHUITimeProfilerHawkeyeAdaptor readCustomEventRecords];
    self.viewModel = [[MTHUITimeProfilerResultViewModel alloc]
        initWithVCAppearRecords:vcAppearedRecords
              detailCostRecords:calltraceRecords
             customEventRecords:customEventsRecords];
}

// MARK: - Private

- (void)showDetailVCWithAppLaunchRecord:(MTHAppLaunchRecord *)record {
    NSInteger numberOfSection = [self.viewModel numberOfSection];
    MTHViewControllerAppearRecord *firstVCRecord;
    NSInteger firstVCRecordSection = 0;
    for (NSInteger i = numberOfSection - 1; i >= 0; i--) {
        firstVCRecord = [self.viewModel vcRecordForSection:i];
        if (firstVCRecord) {
            firstVCRecordSection = i;
            break;
        }
    }

    NSTimeInterval endBefore = firstVCRecord.viewDidAppearExitTime;
    if (endBefore <= 0)
        endBefore = record.appDidLaunchExitTime;

    NSArray *extraRecords = [self.viewModel extraRecordsStartFrom:0 endBefore:endBefore lowerSectionIndex:firstVCRecordSection];

    MTHTimeIntervalStepsViewController *detailVC = [[MTHTimeIntervalStepsViewController alloc] init];
    [detailVC setupWithAppLaunchRecord:record firstVCRecord:firstVCRecord extraRecords:extraRecords];
    [self popoverViewController:detailVC];
}

- (void)showDetailVCWithVCRecord:(MTHViewControllerAppearRecord *)record extraRecords:(NSArray *)extraRecords {
    MTHTimeIntervalStepsViewController *detailVC = [[MTHTimeIntervalStepsViewController alloc] init];
    [detailVC setupWithVCRecord:record extraRecords:extraRecords];
    [self popoverViewController:detailVC];
}

- (void)popoverViewController:(UIViewController *)VC {
    MTHPopoverViewController *popoverVC = [[MTHPopoverViewController alloc] initWithContentViewController:VC fromSourceView:self.view];

    // default system style
    [popoverVC.navigationBar setBarTintColor:nil];
    [popoverVC.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [popoverVC.navigationBar setShadowImage:nil];
    [popoverVC.navigationBar setTitleTextAttributes:nil];

    [self presentViewController:popoverVC animated:YES completion:nil];
}

// MARK: - Action

- (void)rightBarItemAction {
    NSString *calltraceDesc;
    if ([MTHCallTrace isRunning]) {
        double timethreshold = [MTHCallTrace currentTraceTimeThreshold];
        int maxDepth = [MTHCallTrace currentTraceMaxDepth];
        calltraceDesc = [NSString stringWithFormat:@"objc calltrace time_thresolt: %.0fms, max_depth: %d", timethreshold, maxDepth];
    } else {
        calltraceDesc = @" Objective CallTrace off.";
    }

    NSMutableString *logString = [NSMutableString stringWithFormat:@"\n\n[hawkeye][ui-time-profiler] %@\n\n", calltraceDesc];

    NSInteger sectionCount = [self.viewModel numberOfSection];
    for (NSInteger i = 0; i < sectionCount; ++i) {
        MTHTimeProfilerResultViewSection *section = [self.viewModel sectionAtIndex:i];
        [logString appendString:[section description]];

        NSInteger rowCount = [self.viewModel numberOfCellForSection:i];
        for (NSInteger j = 0; j < rowCount; ++j) {
            id model = [self.viewModel cellModelAtIndexPath:[NSIndexPath indexPathForRow:j inSection:i]];
            [logString appendFormat:@"%s\n", [[model description] UTF8String]];
        }
    }
    [logString appendString:@"\n\n"];

#ifdef DEBUG
    printf("%s", logString.UTF8String);
#endif

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[ logString ] applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

// MARK: - MTHTableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.viewModel numberOfSection];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.viewModel numberOfCellForSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL expanded = [self.viewModel cellExpandedForIndexPath:indexPath];

    id model = [self.viewModel cellModelAtIndexPath:indexPath];
    if ([model isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
        return [MTHUITimeProfilerResultCallTraceCell heightForCallTraceTimeCostModel:model expanded:expanded];
    } else if ([model isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
        return [MTHUITImeProfilerResultEventCell heightForEventRecord:model expanded:expanded];
    }

    return 0.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL expanded = [self.viewModel cellExpandedForIndexPath:indexPath];

    id model = [self.viewModel cellModelAtIndexPath:indexPath];
    if ([model isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
        MTHCallTraceTimeCostModel *callTraceModel = (MTHCallTraceTimeCostModel *)model;

        MTHUITimeProfilerResultCallTraceCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MTHUITimeProfilerResultCallTraceCell class]) forIndexPath:indexPath];
        [cell configureWithCallTraceTimeCostModel:callTraceModel expanded:expanded];
        return cell;
    } else if ([model isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
        MTHTimeIntervalCustomEventRecord *eventRecord = (MTHTimeIntervalCustomEventRecord *)model;
        MTHUITImeProfilerResultEventCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MTHUITImeProfilerResultEventCell class]) forIndexPath:indexPath];
        [cell configureWithEventRecord:eventRecord expanded:expanded];
        return cell;
    }

    return nil;
}


// MARK: UITableViewDelegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    MTHUITimeProfilerResultSectionHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass([MTHUITimeProfilerResultSectionHeaderView class])];
    if (!headerView) {
        headerView = [[MTHUITimeProfilerResultSectionHeaderView alloc] init];
    }

    NSTimeInterval timeCostInMS = [self.viewModel timeCostInMSForSection:section];
    NSString *bottomText;
    MTHCallTraceShowDetailBlock showDetailBlock;

    if (timeCostInMS > 0) {
        bottomText = [NSString stringWithFormat:@"%.1fms", timeCostInMS];

        MTHViewControllerAppearRecord *record = [self.viewModel vcRecordForSection:section];
        __weak __typeof(self) weakSelf = self;
        if (record) {
            showDetailBlock = ^{
                NSArray *includedModels = [weakSelf.viewModel cellModelsFor:record atSection:section];
                [weakSelf showDetailVCWithVCRecord:record extraRecords:includedModels];
            };
        } else {
            showDetailBlock = ^{
                [weakSelf showDetailVCWithAppLaunchRecord:[MTHTimeIntervalRecorder shared].launchRecord];
            };
        }
    } else {
        bottomText = @"";
    }

    [headerView setupWithTopText:[self.viewModel titleForSection:section]
                      bottomText:bottomText
                 showDetailBlock:showDetailBlock];

    return headerView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    id model = [self.viewModel cellModelAtIndexPath:indexPath];
    if ([model isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
        MTHCallTraceTimeCostModel *callTraceModel = (MTHCallTraceTimeCostModel *)model;
        if (callTraceModel.subCosts.count > 0) {
            [self.viewModel updateCell:indexPath expanded:![self.viewModel cellExpandedForIndexPath:indexPath]];
            [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
        }
    } else if ([model isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
        MTHTimeIntervalCustomEventRecord *eventRecord = (MTHTimeIntervalCustomEventRecord *)model;
        if (eventRecord.extra.length > 0) {
            [self.viewModel updateCell:indexPath expanded:![self.viewModel cellExpandedForIndexPath:indexPath]];
            [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

// MARK: - Utils

- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = [(MTHawkeyeSettingFoldedCellEntity *)[MTHUITimeProfilerHawkeyeUI settings] foldedSections];
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"UI Time Profiler" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
