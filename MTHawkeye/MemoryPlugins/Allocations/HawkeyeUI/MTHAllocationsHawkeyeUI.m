//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/17
// Created by: EuanC
//


#import "MTHAllocationsHawkeyeUI.h"
#import "MTHAllocationsSettingEntity.h"
#import "MTHAllocationsViewController.h"
#import "MTHawkeyeSettingTableEntity.h"
#import "MTHawkeyeUserDefaults+Allocations.h"


@interface MTHAllocationsHawkeyeUI ()

@end


@implementation MTHAllocationsHawkeyeUI

// MARK: - MTHawkeyeMainPanelPlugin

- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupMemory;
}

- (NSString *)switchingOptionTitle {
    return @"Allocations";
}

- (NSString *)mainPanelIdentity {
    return @"allocations-trace";
}

- (UIViewController *)mainPanelViewController {
    return [[MTHAllocationsViewController alloc] init];
}

// MARK: - MTHawkeyeSettingUIPlugin

+ (NSString *)sectionNameSettingsUnder {
    return kMTHawkeyeUIGroupMemory;
}

+ (MTHawkeyeSettingCellEntity *)settings {
    MTHawkeyeSettingFoldedCellEntity *cell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    cell.title = @"Allocations";
    cell.foldedTitle = cell.title;
    cell.foldedSections = @[
        [self primarySection],
        [self reportsSection],
        [self chunkMallocSection]
    ];
    return cell;
}

+ (MTHawkeyeSettingSectionEntity *)primarySection {
    MTHawkeyeSettingSectionEntity *primary = [[MTHawkeyeSettingSectionEntity alloc] init];
    primary.tag = @"allocations";
    primary.headerText = @"Allocations";
    primary.footerText = @"";
    primary.cells = @[
        [MTHAllocationsSettingEntity loggerSwitcherCell],
        [MTHAllocationsSettingEntity includeSystemFrameSwitcherCell]
    ];
    return primary;
}

+ (MTHawkeyeSettingSectionEntity *)reportsSection {
    MTHawkeyeSettingSectionEntity *reports = [[MTHawkeyeSettingSectionEntity alloc] init];
    reports.tag = @"allocations-report";
    reports.headerText = @"Allocations Reports Configuration";
    reports.footerText = @"";
    reports.cells = @[ [MTHAllocationsSettingEntity mallocReportThresholdEditorCell],
        [MTHAllocationsSettingEntity vmReportThresholdEditorCell],
        [MTHAllocationsSettingEntity reportCategoryElementCountThresholdEditorCell] ];
    return reports;
}

+ (MTHawkeyeSettingSectionEntity *)chunkMallocSection {
    MTHawkeyeSettingSectionEntity *chunkMalloc = [[MTHawkeyeSettingSectionEntity alloc] init];
    chunkMalloc.tag = @"allocations-chunk-malloc";
    chunkMalloc.headerText = @"Chunk Malloc Track";
    chunkMalloc.footerText = @"";
    chunkMalloc.cells = @[ [MTHAllocationsSettingEntity singleChunkMallocSwitcherCell],
        [MTHAllocationsSettingEntity chunkMallocThresholdEditorCell] ];
    return chunkMalloc;
}

@end
