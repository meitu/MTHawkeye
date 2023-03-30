//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 03/07/2017
// Created by: EuanC
//


#import "MTHLivingObjectViewController.h"
#import "MTHLivingObjectGroupInTriggerCell.h"
#import "MTHLivingObjectInfo.h"

#if __has_include(<FBRetainCycleDetector/FBRetainCycleDetector.h>)
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>
#endif

#import <MTHawkeye/MTHToast.h>
#import <MTHawkeye/UITableView+MTHEmptyTips.h>
#import <MTHawkeye/mth_thread_utils.h>


@interface MTHLivingObjectViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, copy) NSArray<MTHLivingObjectGroupInTrigger *> *instancesGroups; // tigger聚合
@property (strong, nonatomic) MTHLivingObjectGroupInClass *instancesGroupInClass;      // 该类下的所有存活对象

@property (nonatomic, copy) NSArray<MTHLivingObjectGroupInTrigger *> *livingInstancesGroups; // 按trigger分类后的存活对象聚合
@property (nonatomic, copy) NSArray<MTHLivingObjectInfo *> *unexpectLivingInstancesGroup;    // 未分类的存活对象聚合

@property (nonatomic, strong) id selectedInstance;
@property (nonatomic, assign) BOOL flexInspectAvailable;
@property (nonatomic, assign) BOOL showDisclosureIndicator;

@property (strong, nonatomic) UITableView *tableView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end


@implementation MTHLivingObjectViewController


- (instancetype)initWithLivingInstancesGroupInClass:(MTHLivingObjectGroupInClass *)groupInClass
                                    groupsInTrigger:(NSArray<MTHLivingObjectGroupInTrigger *> *)groupsInTrigger {
    if ((self = [super init])) {
        _instancesGroups = groupsInTrigger;
        _instancesGroupInClass = groupInClass;


        Class flexObjectExplorerFactory = NSClassFromString(@"FLEXObjectExplorerFactory");
        if (flexObjectExplorerFactory) {
            _flexInspectAvailable = YES;
        }

#if __has_include(<FBRetainCycleDetector/FBRetainCycleDetector.h>)
        _showDisclosureIndicator = YES;
#endif
        if (_flexInspectAvailable) {
            _showDisclosureIndicator = YES;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self buildData];
    [self setupUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.livingInstancesGroups.count == 0 && self.unexpectLivingInstancesGroup.count == 0) {
        [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"The detected instances had released finally."];
    } else {
        [self.tableView mthawkeye_removeEmptyTipsFooterView];
    }
}

- (void)buildData {
    NSMutableArray<MTHLivingObjectGroupInTrigger *> *living = @[].mutableCopy;
    NSMutableArray<MTHLivingObjectInfo *> *unexpectLiving = @[].mutableCopy;
    for (MTHLivingObjectGroupInTrigger *group in self.instancesGroups) {
        for (MTHLivingObjectInfo *objInfo in group.detectedInstances) {
            if (objInfo.instance) {
                [living addObject:group];
                break;
            }
        }
    }

    [living sortUsingComparator:^NSComparisonResult(MTHLivingObjectGroupInTrigger *obj1, MTHLivingObjectGroupInTrigger *obj2) {
        return (obj1.trigger.startTime > obj2.trigger.startTime) ? NSOrderedAscending : NSOrderedDescending;
    }];

    for (MTHLivingObjectInfo *object in self.instancesGroupInClass.aliveInstances) {
        BOOL haveGroup = NO;
        for (MTHLivingObjectGroupInTrigger *group in living) {
            for (MTHLivingObjectInfo *objInfo in group.detectedInstances) {
                if (objInfo.instance == object.instance) {
                    haveGroup = YES;
                    break;
                }
            }
        }
        if (!haveGroup) {
            [unexpectLiving addObject:object];
        }
    }

    self.livingInstancesGroups = living.copy;
    self.unexpectLivingInstancesGroup = unexpectLiving.copy;
}

- (void)setupUI {
    self.title = self.instancesGroupInClass.className;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    [self.tableView registerClass:[MTHLivingObjectGroupInTriggerCell class] forCellReuseIdentifier:@"mth-living-obj-group-cell"];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.view = self.tableView;
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.livingInstancesGroups.count + (self.unexpectLivingInstancesGroup.count ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < self.livingInstancesGroups.count) {
        MTHLivingObjectGroupInTrigger *group = self.livingInstancesGroups[section];
        return group.detectedInstances.count;
    }
    return self.unexpectLivingInstancesGroup.count ? self.unexpectLivingInstancesGroup.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mth-living-obj-cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"mth-living-obj-cell"];
        cell.accessoryType = self.showDisclosureIndicator ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }
    if (indexPath.section < self.livingInstancesGroups.count) {
        MTHLivingObjectGroupInTrigger *group = self.livingInstancesGroups[indexPath.section];
        if (indexPath.row < group.detectedInstances.count) {
            [self updateCellDataInfo:group.detectedInstances[indexPath.row] cell:cell];
        }
    } else if (self.unexpectLivingInstancesGroup.count) {
        if (indexPath.row < self.unexpectLivingInstancesGroup.count) {
            [self updateCellDataInfo:self.unexpectLivingInstancesGroup[indexPath.row] cell:cell];
        }
    }
    return cell;
}

- (void)updateCellDataInfo:(MTHLivingObjectInfo *)obj cell:(UITableViewCell *)cell {
    NSMutableString *instanceDetail = [NSMutableString string];
    [instanceDetail appendFormat:@"pre-holder:%@", obj.preHolderName ?: @""];
    cell.detailTextLabel.text = instanceDetail;

    if (obj.theHodlerIsNotOwner) {
        cell.textLabel.text = [NSString stringWithFormat:@"%p [shared]", (void *)obj.instance];
    } else if (obj.isSingleton) {
        cell.textLabel.text = [NSString stringWithFormat:@"%p [singleton]", (void *)obj.instance];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"%p", (void *)obj.instance];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self headerForSection:section];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (self.livingInstancesGroups.count > 0) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = [self headerForSection:section];
    }
}

- (NSString *)headerForSection:(NSInteger)section {
    if (section < self.livingInstancesGroups.count) {
        MTHLivingObjectGroupInTrigger *group = self.livingInstancesGroups[section];
        NSMutableString *triggerInfo = [NSMutableString string];
        [triggerInfo appendString:[self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:group.trigger.startTime]]];
        [triggerInfo appendString:@"\n"];
        [triggerInfo appendFormat:@"Under: %@", group.trigger.name];
        if (group.trigger.nameExtra) {
            [triggerInfo appendFormat:@"\n  ┗ [children: %@]", group.trigger.nameExtra];
        }
        return triggerInfo.copy;
    } else if (self.unexpectLivingInstancesGroup.count) {
        return @"Unexpected living instances";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == self.tableView.numberOfSections - 1) {
        return @"\n"
               @"[Under] means which object holds the instances indirectly or directly. \n"
               @"[pre-holder] is the class name of the object that hold the instance, and now pre-holder is released. \n"
               @"0xxxxxxxxxx is the memory address of the unexpected alive instance that detected.";
    } else {
        return nil;
    }
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section < self.livingInstancesGroups.count && self.showDisclosureIndicator) {
        MTHLivingObjectGroupInTrigger *group = self.livingInstancesGroups[indexPath.section];
        if (indexPath.row < group.detectedInstances.count) {
            MTHLivingObjectInfo *obj = group.detectedInstances[indexPath.row];
            [self inspectLivingObject:obj];
        }
    } else if (self.unexpectLivingInstancesGroup.count && self.showDisclosureIndicator) {
        if (indexPath.row < self.unexpectLivingInstancesGroup.count) {
            [self inspectLivingObject:self.unexpectLivingInstancesGroup[indexPath.row]];
        }
    }
}

- (void)inspectLivingObject:(MTHLivingObjectInfo *)livingObj {
    if (!livingObj.instance) {
        [[MTHToast shared] showToastWithMessage:@"the instance had released just now" handler:nil];
        return;
    }
    self.selectedInstance = livingObj.instance;
    NSString *title = [NSString stringWithFormat:@"Inspect %p", (void *)livingObj.instance];
    NSString *message = nil;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

#if __has_include(<FBRetainCycleDetector/FBRetainCycleDetector.h>)
    UIAlertAction *retainCycleDetect = [UIAlertAction actionWithTitle:@"FBRetainCycleDetector"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [self tryFBRetainCycleDetector];
                                                              }];
    [alert addAction:retainCycleDetect];
#endif

    UIAlertAction *inspectAction = [UIAlertAction actionWithTitle:@"Object Inspect"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              [self inspectDidTapped];
                                                          }];
    [alert addAction:inspectAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)inspectDidTapped {
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    Class flexObjectExplorerFactory = NSClassFromString(@"FLEXObjectExplorerFactory");
    if (!flexObjectExplorerFactory) {
        return;
    }

    SEL selector = @selector(explorerViewControllerForObject:);

    id vc = [flexObjectExplorerFactory performSelector:selector withObject:self.selectedInstance];
    if ([vc isKindOfClass:[UIViewController class]]) {
        [self.navigationController pushViewController:(UIViewController *)vc animated:YES];
    }
#pragma clang diagnostic pop
}

// MARK: FBRetainCycleDetector
#if __has_include(<FBRetainCycleDetector/FBRetainCycleDetector.h>)

- (void)tryFBRetainCycleDetector {
    if (!self.selectedInstance) {
        return;
    }

    NSString *detectResult = [self retainCycleDetectResultInfoFromCandidate:self.selectedInstance];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FBRetainCycleDetect Result" message:detectResult preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)retainCycleDetectResultInfoFromCandidate:(id)candidate {
    if (!candidate) {
        return nil;
    }

    mth_suspend_all_child_threads();

    FBRetainCycleDetector *detector = [[FBRetainCycleDetector alloc] init];

    [detector addCandidate:candidate];
    NSSet *retainCycles = [detector findRetainCyclesWithMaxCycleLength:10];

    mth_resume_all_child_threads();

    NSMutableString *content = [NSMutableString string];
    for (NSArray *retainCycle in retainCycles) {
        NSInteger index = 0;
        for (FBObjectiveCGraphElement *element in retainCycle) {
            if (element.object == candidate) {
                NSArray *shiftedRetainCycle = [self shiftArray:retainCycle toIndex:index];
                [content appendFormat:@"RetainCycle Detected: \n %@ %@ ", NSStringFromClass([candidate class]), shiftedRetainCycle];
                break;
            }
            ++index;
        }
    }

    if (content.length == 0) {
        [content appendString:@"None retain cycles detected by FBRetainCycle, try 'Xcode Memory Graph'."];
    }

    return content.copy;
}

#endif // __has_include(<FBRetainCycleDetector/FBRetainCycleDetector.h>)

// MARK: help

- (NSArray *)shiftArray:(NSArray *)array toIndex:(NSInteger)index {
    if (index < 0 || index >= array.count) {
        return nil;
    } else if (index == 0) {
        return array;
    }

    NSRange range = NSMakeRange(index, array.count - index);
    if (range.length > 0) {
        return nil;
    }

    NSMutableArray *result = [[array subarrayWithRange:range] mutableCopy];
    [result addObjectsFromArray:[array subarrayWithRange:NSMakeRange(0, index)]];
    return result;
}

// MARK: - getter
- (NSDateFormatter *)dateFormatter {
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"HH:mm:ss:SSS"];
    }
    return _dateFormatter;
}

@end
