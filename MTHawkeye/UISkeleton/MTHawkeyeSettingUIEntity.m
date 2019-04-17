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


#import "MTHawkeyeSettingUIEntity.h"
#import "MTHawkeyeClient.h"
#import "MTHawkeyeSettingTableEntity.h"
#import "MTHawkeyeUIPlugin.h"
#import "MTHawkeyeUserDefaults+UISkeleton.h"


@interface MTHawkeyeSettingUIEntity ()

@property (nonatomic, strong) NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *plugins;
@property (nonatomic, strong) NSMutableArray<id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>> *floatingWidgetCells;

@end


@implementation MTHawkeyeSettingUIEntity

- (instancetype)initWithSettingPlugins:(NSArray<id<MTHawkeyeSettingUIPlugin>> *)settingPlugins
               floatingWidgetSwitchers:(NSArray<id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>> *)floatingWidgetSwitchers {
    if (self = [super init]) {
        self.plugins = settingPlugins.mutableCopy;
        self.floatingWidgetCells = floatingWidgetSwitchers.mutableCopy;
    }
    return self;
}

- (void)addSettingPlugin:(id<MTHawkeyeSettingUIPlugin>)plugin {
    @synchronized(self.plugins) {
        [self.plugins addObject:plugin];
    }
}

- (void)removeSettingPlugin:(id<MTHawkeyeSettingUIPlugin>)plugin {
    @synchronized(self.plugins) {
        [self.plugins removeObject:plugin];
    }
}

- (void)removeAllSettingPlugins {
    @synchronized(self.plugins) {
        [self.plugins removeAllObjects];
        [self.floatingWidgetCells removeAllObjects];
    }
}

- (void)addFloatingWidgetSwitcher:(id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>)plugin {
    @synchronized(self.floatingWidgetCells) {
        [self.floatingWidgetCells addObject:plugin];
    }
}

- (void)removeFloatingWidgetSwitcher:(id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>)pluginToRemove {
    @synchronized(self.floatingWidgetCells) {
        [self.floatingWidgetCells removeObject:pluginToRemove];
    }
}

- (void)removeAllFloatingWidget {
    @synchronized(self.floatingWidgetCells) {
        [self.floatingWidgetCells removeAllObjects];
    }
}

- (MTHawkeyeSettingTableEntity *)settingViewModelEntity {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    NSMutableArray<MTHawkeyeSettingSectionEntity *> *sections = @[].mutableCopy;
    [sections addObject:[self hawkeyePrimarySection]];

    NSMutableDictionary *sectionsDict = @{}.mutableCopy;
    for (id<MTHawkeyeSettingUIPlugin> plugin in self.plugins) {
        NSString *sectionName = [[plugin class] sectionNameSettingsUnder];
        MTHawkeyeSettingSectionEntity *section = nil;
        section = [sectionsDict objectForKey:sectionName];
        if (!section) {
            section = [[MTHawkeyeSettingSectionEntity alloc] init];
            section.headerText = sectionName;
            sectionsDict[sectionName] = section;
            [sections addObject:section];
        }

        NSMutableArray<MTHawkeyeSettingCellEntity *> *cells = section.cells ? section.cells.mutableCopy : @[].mutableCopy;
        [cells addObject:[[plugin class] settings]];
        section.cells = cells.copy;
    }

    entity.sections = sections;
    return entity;
}

// MARK: - Primary Section

- (MTHawkeyeSettingSectionEntity *)hawkeyePrimarySection {
    MTHawkeyeSettingSectionEntity *section = [[MTHawkeyeSettingSectionEntity alloc] init];
    section.tag = @"primary";
    section.cells = @[
        [self hawkeyeMainSwitcherCell],
        [self floatingWindowFoldedCell]
    ];
    return section;
}

- (MTHawkeyeSettingCellEntity *)hawkeyeMainSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Hawkeye";
    cell.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].hawkeyeOn;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if ([MTHawkeyeUserDefaults shared].hawkeyeOn == newValue)
            return NO;

        [MTHawkeyeUserDefaults shared].hawkeyeOn = newValue;
        return YES;
    };
    return cell;
}

- (MTHawkeyeSettingFoldedCellEntity *)floatingWindowFoldedCell {
    MTHawkeyeSettingFoldedCellEntity *foldedCell = [[MTHawkeyeSettingFoldedCellEntity alloc] init];
    foldedCell.title = @"Floating Window";
    foldedCell.foldedTitle = @"Floating Window";

    MTHawkeyeSettingSectionEntity *primarySection = [[MTHawkeyeSettingSectionEntity alloc] init];
    primarySection.cells = @[ [self hawkeyeFloatingWindowSwitcherCell],
        [self hawkeyeFloatingWindowShowHideGestureSwitcherCell] ];
    [foldedCell insertSection:primarySection atIndex:0];

    [foldedCell insertSection:self.floatingWindowWidgetsSection atIndex:1];

    return foldedCell;
}

- (MTHawkeyeSettingSectionEntity *)floatingWindowWidgetsSection {
    MTHawkeyeSettingSectionEntity *floatingWindowWidgetsSection = [[MTHawkeyeSettingSectionEntity alloc] init];
    for (id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin> plugin in self.floatingWidgetCells) {
        [floatingWindowWidgetsSection addCell:[plugin floatingWidgetSwitcher]];
    }

    floatingWindowWidgetsSection.footerText = @"GPU MEMORY depends on Graphics-OpenGL Trace";

    return floatingWindowWidgetsSection;
}

- (MTHawkeyeSettingCellEntity *)hawkeyeFloatingWindowSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Floating Window";
    cell.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].displayFloatingWindow;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if ([MTHawkeyeUserDefaults shared].displayFloatingWindow == newValue)
            return NO;

        [MTHawkeyeUserDefaults shared].displayFloatingWindow = newValue;
        return YES;
    };
    return cell;
}

- (MTHawkeyeSettingCellEntity *)hawkeyeFloatingWindowShowHideGestureSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *cell = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    cell.title = @"Show/Hide Gesture";
    cell.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].floatingWindowShowHideGesture;
    };
    cell.valueChangedHandler = ^BOOL(BOOL newValue) {
        if ([MTHawkeyeUserDefaults shared].floatingWindowShowHideGesture == newValue)
            return NO;

        [MTHawkeyeUserDefaults shared].floatingWindowShowHideGesture = newValue;
        return YES;
    };
    return cell;
}

@end
