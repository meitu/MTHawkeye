//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/9
// Created by: EuanC
//


#import "MTHawkeyeMainPanels.h"
#import "MTHawkeyeMainPanelViewController.h"
#import "MTHawkeyeUIPlugin.h"

@interface MTHawkeyeMainPanels ()

@property (nonatomic, strong) NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *rawPlugins;

@property (nonatomic, strong) NSMutableArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *> *sectionPanelsGroups;

@end

@implementation MTHawkeyeMainPanels

- (instancetype)initWithMainPanelPlugins:(NSArray<id<MTHawkeyeMainPanelPlugin>> *)plugins {
    if (self = [super init]) {
        for (id<MTHawkeyeMainPanelPlugin> plugin in plugins)
            [self checkPluginImplement:plugin];

        _rawPlugins = plugins.mutableCopy;
        _sectionTitles = @[].mutableCopy;
        _sectionPanelsGroups = @[].mutableCopy;

        for (id<MTHawkeyeMainPanelPlugin> plugin in plugins) {
            [self doAddPanelPluginToGroup:plugin];
        }
    }
    return self;
}

- (void)addMainPanelPlugin:(id<MTHawkeyeMainPanelPlugin>)plugin {
    [self checkPluginImplement:plugin];

    @synchronized(self.sectionPanelsGroups) {
        [self doAddPanelPluginToGroup:plugin];
    }
    @synchronized(self.rawPlugins) {
        [self.rawPlugins addObject:plugin];
    }
}

- (void)doAddPanelPluginToGroup:(id<MTHawkeyeMainPanelPlugin>)plugin {
    NSString *pluginGroupUnder = [plugin groupNameSwitchingOptionUnder];
    NSUInteger index = [self.sectionTitles indexOfObjectPassingTest:^BOOL(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        return [obj isEqualToString:pluginGroupUnder];
    }];

    NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *groupPanels;
    if (index == NSNotFound) {
        [self.sectionTitles addObject:pluginGroupUnder];
        groupPanels = @[].mutableCopy;
        [self.sectionPanelsGroups addObject:groupPanels];
    } else {
        groupPanels = self.sectionPanelsGroups[index];
    }

    [groupPanels addObject:plugin];
}

- (void)removeMainPanelPlugin:(id<MTHawkeyeMainPanelPlugin>)plugin {
    @synchronized(self.sectionPanelsGroups) {
        for (NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *groupPanels in self.sectionPanelsGroups) {
            [groupPanels removeObject:plugin];
        }
    }
    @synchronized(self.rawPlugins) {
        [self.rawPlugins removeObject:plugin];
    }
}

- (id<MTHawkeyeMainPanelPlugin>)pluginAtIndexPath:(NSIndexPath *)indexPath {
    @synchronized(self.sectionPanelsGroups) {
        if (indexPath.section >= self.sectionPanelsGroups.count)
            return nil;

        NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *group = self.sectionPanelsGroups[indexPath.section];
        if (indexPath.row >= group.count)
            return nil;

        return group[indexPath.row];
    }
}

- (void)checkPluginImplement:(id<MTHawkeyeMainPanelPlugin>)plugin {
    if (![plugin respondsToSelector:@selector(switchingOptionTitle)])
        NSAssert(NO, @"%@ should have a title by implement `switchingOptionTitle`", plugin);

    if (![plugin respondsToSelector:@selector(groupNameSwitchingOptionUnder)])
        NSAssert(NO, @"%@ should place the panel under a group by implement `groupNameSwitchingOptionUnder`", plugin);

    if (![plugin respondsToSelector:@selector(mainPanelViewController)]) {
        if (![plugin respondsToSelector:@selector(switchingOptionTriggerCustomAction)]) {
            NSAssert(NO, @"%@ havn't implement `mainPanelViewController` or `switchingOptionTriggerCustomAction`, you should implement one of them.", plugin);
        } else {
            if ([plugin respondsToSelector:@selector(switchingOptionTriggerCustomAction)] && ![plugin respondsToSelector:@selector(switchingOptionDidTapped)]) {
                NSAssert(NO, @"%@ want to trigger custom action, but havn't implement `switchingOptionDidTapped`.", plugin);
            }
        }
    }
}

// MARK: - MTHawkeyeMainPanelViewControllerDatasource
- (NSIndexPath *)indexPathForPanelID:(NSString *)panelID {
    @synchronized(self.sectionPanelsGroups) {
        NSInteger section = -1, row = -1;
        for (NSInteger i = 0; i < self.sectionPanelsGroups.count; ++i) {
            NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *group = self.sectionPanelsGroups[i];
            for (NSInteger j = 0; j < group.count; ++j) {
                id<MTHawkeyeMainPanelPlugin> plugin = group[j];
                if ([plugin respondsToSelector:@selector(mainPanelIdentity)] && [[plugin mainPanelIdentity] isEqualToString:panelID]) {
                    section = i;
                    row = j;
                    break;
                }
            }
            if (section != -1)
                break;
        }

        return [NSIndexPath indexPathForRow:row inSection:section];
    }
}

- (NSString *)panelViewControllerTitleForSwitcherOptionAtIndexPath:(NSIndexPath *)indexPath {
    id<MTHawkeyeMainPanelPlugin> plugin = [self pluginAtIndexPath:indexPath];
    if (!plugin)
        return nil;

    if ([plugin respondsToSelector:@selector(mainPanelTitle)]) {
        return [plugin mainPanelTitle] ?: @"";
    } else {
        return nil;
    }
}

- (UIViewController *)panelViewControllerForSwitcherOptionAtIndexPath:(NSIndexPath *)indexPath {
    id<MTHawkeyeMainPanelPlugin> plugin = [self pluginAtIndexPath:indexPath];
    if (!plugin)
        return nil;

    if (![plugin respondsToSelector:@selector(mainPanelViewController)])
        return nil;

    UIViewController *panel = [plugin mainPanelViewController];
    return panel;
}

// MARK: - MTHawkeyeMainPanelSwitcherDelegate

- (NSInteger)numberOfSwitcherOptionsSection {
    return self.sectionPanelsGroups.count;
}

- (NSInteger)numberOfSwitcherOptionsRowAtSection:(NSInteger)section {
    @synchronized(self.sectionPanelsGroups) {
        if (section >= self.sectionPanelsGroups.count)
            return 0;
        else
            return self.sectionPanelsGroups[section].count;
    }
}

- (NSString *)switcherOptionsSectionTitleAtIndex:(NSInteger)index {
    @synchronized(self.sectionPanelsGroups) {
        if (index >= self.sectionTitles.count)
            return nil;
        else
            return self.sectionTitles[index];
    }
}

- (NSString *)switcherOptionsTitleAtIndexPath:(NSIndexPath *)indexPath {
    id<MTHawkeyeMainPanelPlugin> plugin = [self pluginAtIndexPath:indexPath];
    if (!plugin)
        return nil;

    return [plugin switchingOptionTitle];
}

- (BOOL)shouldChangeSelectStatusToNew:(NSIndexPath *)newSelectIndexPath fromOld:(NSIndexPath *)oldSelectIndexPath {
    id<MTHawkeyeMainPanelPlugin> plugin = [self pluginAtIndexPath:newSelectIndexPath];
    if (!plugin)
        return NO;

    if ([plugin respondsToSelector:@selector(mainPanelViewController)]) {
        return YES;
    }
    if ([plugin respondsToSelector:@selector(switchingOptionTriggerCustomAction)]) {
        return ![plugin switchingOptionTriggerCustomAction];
    }
    return NO;
}

- (void)panelSwitcherDidSelectAtIndexPath:(NSIndexPath *)indexPath {
    id<MTHawkeyeMainPanelPlugin> plugin = [self pluginAtIndexPath:indexPath];
    if (!plugin)
        return;

    if ([plugin respondsToSelector:@selector(switchingOptionDidTapped)]) {
        [plugin switchingOptionDidTapped];
    }
}

// MARK: - getter
- (NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *)plugins {
    @synchronized(self.rawPlugins) {
        return self.rawPlugins;
    }
}

@end
