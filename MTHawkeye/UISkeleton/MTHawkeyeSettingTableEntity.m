//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/14
// Created by: EuanC
//


#import "MTHawkeyeSettingTableEntity.h"

@implementation MTHawkeyeSettingTableEntity

@end

@implementation MTHawkeyeSettingSectionEntity

- (void)addCell:(MTHawkeyeSettingCellEntity *)cell {
    [self insertCell:cell atIndex:self.cells.count];
}

- (void)insertCell:(MTHawkeyeSettingCellEntity *)cell atIndex:(NSUInteger)index {
    if (index > self.cells.count) {
        NSAssert(NO, @"setting cell insert index out of range.");
        return;
    }

    NSMutableArray *cells = self.cells ? self.cells.mutableCopy : @[].mutableCopy;
    [cells insertObject:cell atIndex:index];
    self.cells = cells.copy;
}

- (void)removeCellByTag:(NSString *)cellTag {
    for (MTHawkeyeSettingCellEntity *cell in self.cells) {
        if ([cell.tag isEqualToString:cellTag]) {
            NSMutableArray *newCells = [self.cells copy];
            [newCells removeObject:cell];
            self.cells = [newCells copy];
            break;
        }
    }
}

@end

@implementation MTHawkeyeSettingCellEntity

@end

@implementation MTHawkeyeSettingFoldedCellEntity

- (void)addSection:(MTHawkeyeSettingSectionEntity *)section {
    [self insertSection:section atIndex:self.foldedSections.count];
}

- (void)insertSection:(MTHawkeyeSettingSectionEntity *)section atIndex:(NSUInteger)insertTo {
    if (insertTo > self.foldedSections.count) {
        NSAssert(NO, @"setting section insert index out of range.");
        return;
    }

    NSMutableArray *sections = self.foldedSections ? self.foldedSections.mutableCopy : @[].mutableCopy;
    [sections insertObject:section atIndex:insertTo];
    self.foldedSections = sections.copy;
}

- (void)insertCell:(MTHawkeyeSettingCellEntity *)cell atIndexPath:(NSIndexPath *)insertTo {
    if (insertTo.section > self.foldedSections.count) {
        NSAssert(NO, @"setting section insert index out of range.");
        return;
    }

    MTHawkeyeSettingSectionEntity *section = [self.foldedSections objectAtIndex:insertTo.section];
    if (section == nil) {
        section = [[MTHawkeyeSettingSectionEntity alloc] init];
        [self insertSection:section atIndex:insertTo.section];
    }

    [section insertCell:cell atIndex:insertTo.row];
}

@end

@implementation MTHawkeyeSettingEditorCellEntity

@end

@implementation MTHawkeyeSettingSwitcherCellEntity

@end

@implementation MTHawkeyeSettingSelectorCellEntity

@end

@implementation MTHawkeyeSettingActionCellEntity

@end


// MARK: - Factory
//@implementation MTHawkeyeSettingViewModelEntityFactory
//
//+ (MTHawkeyeSettingTableEntity *)twoStageSettingWithFirstStageCellTitle:(NSString *)firstStageCellTitle
//                                                   secondStageMultiSections:(NSArray<MTHawkeyeSettingSectionEntity *> *)secondStageSections {
//
//}
//
//+ (MTHawkeyeSettingTableEntity *)twoStageSettingWithFirstStageCellTitle:(NSString *)firstStageCellTitle
//                                                   secondStageSingleSection:(MTHawkeyeSettingSectionEntity *)secondStageSingleSection {
//
//}
//
//+ (MTHawkeyeSettingTableEntity *)twoStageSettingWithFirstStageSectionTitle:(NSString *)firstStageSectionTitle
//                                                      secondStageMultiSections:(NSArray<MTHawkeyeSettingSectionEntity *> *)secondStageSections {
//
//}
//
//+ (MTHawkeyeSettingTableEntity *)twoStageSettingWithFirstStageSectionTitle:(NSString *)firstStageSectionTitle
//                                                      secondStageSingleSection:(MTHawkeyeSettingSectionEntity *)secondStageSingleSection {
//    MTHawkeyeSettingSectionEntity *surfaceSection = [[MTHawkeyeSettingSectionEntity alloc] init];
//    surfaceSection.cells = @[[self allocationsSurfaceCell]];
//    surfaceSection.headerText = @"";
//    surfaceSection.footerText = @"";
//
//    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
//}
//
//+ (MTHawkeyeSettingTableEntity *)surfaceCellWithTitle:(NSString *)title
//                                         expandedSections:(NSArray<MTHawkeyeSettingSectionEntity *> *)sections {
//    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
//    entity.sections = sections;
//
//    MTHawkeyeSettingFoldedCellEntity *surfaceCell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
//    surfaceCell.detail = entity;
//    surfaceCell.title = title;
//    return entity;
//}
//
//+ (MTHawkeyeSettingTableEntity *)surfaceCellWithtTitle:(NSString *)surfaceTitle
//                                             expandedCells:(NSArray<MTHawkeyeSettingCellEntity *> *)cells {
//    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
//    section.cells = cells;
//    section.headerText = @"";
//    section.footerText = @"";
//
//    return [self surfaceCellWithTitle:surfaceTitle expandedSections:@[section]];
//}
//
//@end
