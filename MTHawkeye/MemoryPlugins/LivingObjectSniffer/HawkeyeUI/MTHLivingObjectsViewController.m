//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import "MTHLivingObjectsViewController.h"
#import "MTHLivingObjectInfo.h"
#import "MTHLivingObjectSniffService.h"
#import "MTHLivingObjectViewController.h"
#import "MTHLivingObjectsSnifferHawkeyeUI.h"
#import "MTHMonitorChartView.h"
#import "MTHawkeyeSettingViewController.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults+LivingObjectsSniffer.h"
#import "MTHawkeyeUtility.h"
#import "MTHawkeyeWebViewController.h"
#import "UITableView+MTHEmptyTips.h"
#import "UIViewController+MTHawkeyeLayoutSupport.h"


@interface MTHLivingObjectsViewController () <MTHMonitorChartViewDelegate, MTHLivingObjectSnifferDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MTHMonitorChartView *chartView;

@property (nonatomic, copy) NSArray<MTHLivingObjectGroupInClass *> *livingObjectGroups;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *memoryUsageHistory;

@property (nonatomic, copy) NSArray<MTHLivingObjectShadowTrigger *> *triggers;

@property (nonatomic, assign) NSInteger detailLoadingIndex;

@end

@implementation MTHLivingObjectsViewController

- (instancetype)init {
    if ((self = [super init])) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.detailLoadingIndex = -1;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.view = self.tableView;

    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, 180);
    self.chartView = [[MTHMonitorChartView alloc] initWithFrame:frame];
    self.chartView.delegate = self;
    self.chartView.unitLabelTitle = @"MB";
    self.tableView.tableHeaderView = self.chartView;

    self.title = @"Unexpect Living Object";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self reloadTableView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[MTHLivingObjectSniffService shared].sniffer addDelegate:self];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [[MTHLivingObjectSniffService shared].sniffer removeDelegate:self];
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

/****************************************************************************/
#pragma mark - MTHLivingObjectSnifferDelegate

- (void)livingObjectSniffer:(MTHLivingObjectSniffer *)sniffer didSniffOutResult:(MTHLivingObjectShadowPackageInspectResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self reloadTableView];
    });
}

/****************************************************************************/
#pragma mark -

- (void)reloadTableView {
    [self loadData];
    [self.tableView reloadData];

    if ([self.livingObjectGroups count] == 0) {
        if (![MTHawkeyeUserDefaults shared].livingObjectsSnifferOn) {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Living Objective-C object tracing is OFF"
                                                         tipsTop:45.f
                                                          button:@"Go to Setting"
                                                       btnTarget:self
                                                       btnAction:@selector(gotoSetting)];
        } else {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Empty Records"];
        }
    } else {
        [self.tableView mthawkeye_removeEmptyTipsFooterView];
    }
}

- (void)loadData {
    NSArray *times;
    NSArray *memRecords;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"r-mem" keys:&times values:&memRecords];

    NSMutableArray<NSNumber *> *memoryUsageHistory = [NSMutableArray arrayWithCapacity:memRecords.count];
    [memRecords enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [memoryUsageHistory addObject:@(obj.doubleValue)];
    }];
    self.memoryUsageHistory = memoryUsageHistory;

    self.livingObjectGroups = [MTHLivingObjectSniffService shared].sniffer.livingObjectGroupsInClass;

    // reload triggers if need.
    if (_triggers != nil) {
        _triggers = nil;
    }
}

// MARK: - MTHMonitorChartViewDelegate
- (NSInteger)numberOfPointsInChartView:(MTHMonitorChartView *)chartView {
    return self.memoryUsageHistory.count;
}

- (CGFloat)chartView:(MTHMonitorChartView *)chartView valueForPointAtIndex:(NSInteger)index {
    return [self.memoryUsageHistory[index] floatValue];
}

// MARK: - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.livingObjectGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView unexpectedLivingInstanceCellAtIndexPath:indexPath];
}

- (UITableViewCell *_Nonnull)tableView:(UITableView *_Nonnull)tableView unexpectedLivingInstanceCellAtIndexPath:(NSIndexPath *_Nonnull)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"unexpect-living-objs-cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"unexpect-living-objs-cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.row < self.livingObjectGroups.count) {
        MTHLivingObjectGroupInClass *group = self.livingObjectGroups[indexPath.row];
        NSInteger aliveInstanceCount = group.aliveInstanceCount;
        NSArray<MTHLivingObjectInfo *> *aliveInstances = group.aliveInstances;
        NSInteger sharedCount = 0;
        for (MTHLivingObjectInfo *aliveInst in aliveInstances) {
            if (aliveInst.theHodlerIsNotOwner || aliveInst.isSingleton)
                sharedCount++;
        }
        cell.textLabel.text = [NSString stringWithFormat:@"%@", group.className];

        NSInteger blackColorLevel = 0;
        NSMutableString *desc = [NSMutableString string];
        if (aliveInstanceCount == 0) {
            [desc appendString:@"[all released]"];
            blackColorLevel = 3;
        } else {
            if (sharedCount > 0) {
                [desc appendFormat:@"[shared: %ld]", (long)sharedCount];
                blackColorLevel = 2;
            }
            if (aliveInstanceCount > sharedCount) {
                if (desc.length > 0) {
                    [desc appendString:@", "];
                    [desc appendFormat:@"[others living: %@]", @(aliveInstanceCount - sharedCount)];
                } else {
                    [desc appendFormat:@"[living: %@]", @(aliveInstanceCount - sharedCount)];
                }
            }
        }

        if (blackColorLevel <= 2) {
            cell.textLabel.textColor = [UIColor blackColor];
            cell.detailTextLabel.textColor = [UIColor blackColor];
        } else {
            cell.textLabel.textColor = [UIColor lightGrayColor];
            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        }

        cell.detailTextLabel.text = desc;
    } else {
        cell.textLabel.text = @"";
    }

    if (self.detailLoadingIndex == indexPath.row) {
        UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        cell.accessoryView = loadingView;
        [loadingView startAnimating];
    } else {
        cell.accessoryView = nil;
    }

    return cell;
}

// MARK: UITableViewDelegate
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Unexcepted living instances";
    }
    return @"";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (section == 0) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = @"Unexcepted living instances";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.livingObjectGroups.count == 0)
        return nil;

    if (section == 0) {
        return @"[shared] the count of instances that has been detected more than one time, the instance should be retained by other holders and is shared. \n\n";
    }
    return @"";
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.detailLoadingIndex < 0)
        return YES;
    else
        return self.detailLoadingIndex == indexPath.row;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.detailLoadingIndex >= 0)
        return;

    if (indexPath.row < self.livingObjectGroups.count) {
        self.detailLoadingIndex = indexPath.row;

        [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            MTHLivingObjectGroupInClass *group = self.livingObjectGroups[indexPath.row];
            NSArray<MTHLivingObjectGroupInTrigger *> *groupsInTrigger = [self triggerLivingObjectsForGroup:group];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                self.detailLoadingIndex = -1;
                [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
                [tableView deselectRowAtIndexPath:indexPath animated:YES];

                MTHLivingObjectViewController *vc = [[MTHLivingObjectViewController alloc] initWithLivingInstancesGroupInClass:group groupsInTrigger:groupsInTrigger];
                [self.navigationController pushViewController:vc animated:YES];
            });
        });
    }
}

// MARK: - triggers

- (NSArray<MTHLivingObjectGroupInTrigger *> *)triggerLivingObjectsForGroup:(MTHLivingObjectGroupInClass *)objsGroupInClass {
    NSMutableArray<MTHLivingObjectGroupInTrigger *> *result = @[].mutableCopy;
    for (MTHLivingObjectShadowTrigger *trigger in self.triggers) {

        MTHLivingObjectGroupInTrigger *groupInTrigger = nil;
        for (MTHLivingObjectInfo *livingObj in objsGroupInClass.aliveInstances) {
            if (livingObj.recordTime > trigger.startTime && livingObj.recordTime < trigger.endTime) {
                if (groupInTrigger == nil) {
                    groupInTrigger = [[MTHLivingObjectGroupInTrigger alloc] init];
                    groupInTrigger.trigger = trigger;
                    groupInTrigger.detectedInstances = @[ livingObj ];
                    [result addObject:groupInTrigger];
                } else {
                    NSMutableArray *instances = groupInTrigger.detectedInstances.mutableCopy;
                    [instances addObject:livingObj];
                    groupInTrigger.detectedInstances = instances;
                }
            }
        }
    }
    return result.copy;
}

- (NSArray<MTHLivingObjectShadowTrigger *> *)triggers {
    if (_triggers == nil) {
        NSArray<NSString *> *values;
        [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"obj-shadow-trigger" keys:nil values:&values];

        NSMutableArray *triggers = @[].mutableCopy;
        for (NSString *triggerInfo in values) {
            NSData *triggerData = [triggerInfo dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error;
            NSDictionary *triggerDict = [NSJSONSerialization JSONObjectWithData:triggerData options:0 error:&error];
            if (!error) {
                MTHLivingObjectShadowTrigger *trigger = [[MTHLivingObjectShadowTrigger alloc] initWithDictionary:triggerDict];
                if (trigger.type != MTHLivingObjectShadowTriggerTypeUnknown) {
                    [triggers addObject:trigger];
                }
            }
        }

        _triggers = triggers.copy;
    }
    return _triggers;
}

// MARK: - Utils

- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *setEntity = [[MTHawkeyeSettingTableEntity alloc] init];
    setEntity.sections = [(MTHawkeyeSettingFoldedCellEntity *)[MTHLivingObjectsSnifferHawkeyeUI settings] foldedSections];
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"LivingObjectsSniffer" viewModelEntity:setEntity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
