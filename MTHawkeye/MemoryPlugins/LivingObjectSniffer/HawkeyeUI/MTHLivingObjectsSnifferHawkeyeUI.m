//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import "MTHLivingObjectsSnifferHawkeyeUI.h"
#import "MTHLivingObjectSniffService.h"
#import "MTHLivingObjectsSnifferHawkeyeAdaptor.h"
#import "MTHLivingObjectsViewController.h"
#import "MTHawkeyeUserDefaults+LivingObjectsSniffer.h"

#import <MTHawkeye/MTHToast.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/MTHawkeyeUIClient.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+UISkeleton.h>


@interface MTHLivingObjectsSnifferHawkeyeUI () <MTHLivingObjectSnifferDelegate>

@end


@implementation MTHLivingObjectsSnifferHawkeyeUI

- (void)dealloc {
    [[MTHLivingObjectSniffService shared].sniffer removeDelegate:self];
}

- (instancetype)init {
    if (self = [super init]) {
        [[MTHLivingObjectSniffService shared].sniffer addDelegate:self];
    }
    return self;
}


// MARK: - MTHLivingObjectSnifferDelegate

NSInteger gHawkeyeWarningUnexpectedLivingCellViewCount = 20;
NSInteger gHawkeyeWarningUnexpectedLivingViewCount = 5;
CGFloat gHawkeyeWarningUnexpectedLivingObjectFlashDuration = 5.f;

- (void)livingObjectSniffer:(MTHLivingObjectSniffer *)sniffer
          didSniffOutResult:(MTHLivingObjectShadowPackageInspectResult *)result {
    if (![MTHawkeyeUserDefaults shared].displayFloatingWindow)
        return;

    for (MTHLivingObjectShadowPackageInspectResultItem *item in result.items) {
        MTHLivingObjectGroupInClass *group = item.theGroupInClass;

        // 1. ignore first time (may be shared instances)
        if ([group aliveInstanceCount] == item.livingObjectsNew.count)
            return;

        for (MTHLivingObjectInfo *objInfo in item.livingObjectsNew) {
            if (objInfo.theHodlerIsNotOwner || objInfo.isSingleton)
                return;
        }

        MTHLivingObjectInfo *objInfo = item.livingObjectsNew.firstObject;
        if ([objInfo.instance isKindOfClass:UIViewController.class] && [self.class shouldRaiseToastWarningForVC]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[MTHToast shared] showToastWithStyle:MTHToastStyleSimple
                                                title:nil
                                              content:[NSString stringWithFormat:@"%@ Still Alive", NSStringFromClass([objInfo.instance class])]
                                        detailContent:nil
                                             duration:3.f
                                              handler:^{
                                                  [[MTHawkeyeUIClient shared] showMainPanelWithSelectedID:[self mainPanelIdentity]];
                                              }
                                       buttonHandlers:nil
                                 autoHiddenBeOccluded:YES];
            });
        } else if ([objInfo.instance isKindOfClass:UIView.class]) {
            if ([objInfo.instance isKindOfClass:UITableViewCell.class] || [objInfo.instance isKindOfClass:UICollectionViewCell.class]) {
                if ([group aliveInstanceCount] <= gHawkeyeWarningUnexpectedLivingCellViewCount)
                    return;
            } else {
                if ([group aliveInstanceCount] <= gHawkeyeWarningUnexpectedLivingViewCount)
                    return;
            }
        }

        NSDictionary *params = @{
            kMTHFloatingWidgetRaiseWarningParamsPanelIDKey : [self mainPanelIdentity],
            kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey : @(gHawkeyeWarningUnexpectedLivingObjectFlashDuration),
        };
        [[MTHawkeyeUIClient shared] raiseWarningOnFloatingWidget:@"mem" withParams:params];
    }
}

// MARK: - MTHawkeyeMainPanelPlugin

- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupMemory;
}

- (NSString *)switchingOptionTitle {
    return @"Memory Records";
}

- (NSString *)mainPanelIdentity {
    return @"memory-records";
}

- (UIViewController *)mainPanelViewController {
    MTHLivingObjectsViewController *vc = [[MTHLivingObjectsViewController alloc] init];
    return vc;
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupMemory;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"Living Objects Sniffer";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [self livingObjSnifferSectionEntity],
        [self livingObjSnifferWarningSectionEntity],
    ];
    return cell;
}

+ (MTHawkeyeSettingSectionEntity *)livingObjSnifferSectionEntity {
    MTHawkeyeSettingSectionEntity *primarySection = [[MTHawkeyeSettingSectionEntity alloc] init];
    primarySection.tag = @"living-objc-objects";
    primarySection.headerText = @"Living Objects Sniffer";
    primarySection.footerText = @"The unexcepted living Objective-C object tracing related to ViewController's life, see the document for detail.";
    primarySection.cells = @[
        [self primarySwitcherCell],
        [self enableSnifferContainerSwitcherCell]
    ];
    return primarySection;
}

+ (MTHawkeyeSettingSectionEntity *)livingObjSnifferWarningSectionEntity {
    MTHawkeyeSettingSectionEntity *primarySection = [[MTHawkeyeSettingSectionEntity alloc] init];
    primarySection.headerText = @"Warning UI Configuration";
    primarySection.footerText = @"Whether raise a toast warning when detected an unexpected ViewController.";
    primarySection.cells = @[
        [self toastWarnForVCSwitcherCell]
    ];
    return primarySection;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)primarySwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Living Objects Sniffer";
    cell.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].livingObjectsSnifferOn;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].livingObjectsSnifferOn) {
            [MTHawkeyeUserDefaults shared].livingObjectsSnifferOn = newValue;
            return YES;
        }
        return NO;
    };
    return cell;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)enableSnifferContainerSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Sniff NSFoundation Container";
    cell.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].livingObjectsSnifferContainerSniffEnabled;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].livingObjectsSnifferContainerSniffEnabled) {
            [MTHawkeyeUserDefaults shared].livingObjectsSnifferContainerSniffEnabled = newValue;
            return YES;
        }
        return NO;
    };
    return cell;
}

+ (BOOL)shouldRaiseToastWarningForVC {
    id value = [[MTHawkeyeUserDefaults shared] objectForKey:@"toast-warning-for-unexpected-vc"];
    return value ? [value boolValue] : YES;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)toastWarnForVCSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Toast Warning For Unexpected VC";
    cell.setupValueHandler = ^BOOL {
        return [self shouldRaiseToastWarningForVC];
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        bool oldValue = [self shouldRaiseToastWarningForVC];
        if (newValue != oldValue) {
            [[MTHawkeyeUserDefaults shared] setValue:@(newValue) forKey:@"toast-warning-for-unexpected-vc"];
            return YES;
        }
        return NO;
    };
    return cell;
}

@end
