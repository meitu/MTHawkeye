//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#import "MTHawkeyeFloatingWidgets.h"

@interface MTHawkeyeFloatingWidgets () <MTHawkeyeFloatingWidgetDelegate>

@property (nonatomic, strong) NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *plugins;

@property (nonatomic, strong) NSMutableArray<MTHMonitorViewCell *> *cells;
@property (nonatomic, strong) NSMutableArray<MTHMonitorViewCell *> *visibleCells;

@end


@implementation MTHawkeyeFloatingWidgets

- (instancetype)init {
    if (self = [super init]) {
        _plugins = @[].mutableCopy;
        _cells = @[].mutableCopy;
        _visibleCells = @[].mutableCopy;
    }
    return self;
}

- (instancetype)initWithWidgets:(NSArray<id<MTHawkeyeFloatingWidgetPlugin>> *)widgets {
    if (self = [super init]) {
        _plugins = @[].mutableCopy;
        _cells = @[].mutableCopy;
        _visibleCells = @[].mutableCopy;

        for (id<MTHawkeyeFloatingWidgetPlugin> widget in widgets) {
            widget.delegate = self;
            [_plugins addObject:widget];
        }
    }
    return self;
}

- (void)addWidget:(id<MTHawkeyeFloatingWidgetPlugin>)plugin {
    @synchronized(self.plugins) {
        plugin.delegate = self;
        [self.plugins addObject:plugin];

        if (self.cells.count > 0)
            [self rebuildDatasource];
    }
}

- (void)removeWidget:(id<MTHawkeyeFloatingWidgetPlugin>)plugin {
    @synchronized(self.plugins) {
        plugin.delegate = nil;
        [self.plugins removeObject:plugin];

        if (self.cells.count > 0)
            [self rebuildDatasource];
    }
}

- (id<MTHawkeyeFloatingWidgetPlugin>)widgetFromID:(NSString *)widgetID {
    @synchronized(self.plugins) {
        for (id<MTHawkeyeFloatingWidgetPlugin> plugin in self.plugins) {
            if ([plugin respondsToSelector:@selector(widgetIdentity)]) {
                if ([[plugin widgetIdentity] isEqualToString:widgetID])
                    return plugin;
            }
        }
    }
    return nil;
}

- (void)buildCells {
    [self.cells removeAllObjects];
    [self.visibleCells removeAllObjects];

    @synchronized(self.plugins) {
        for (id<MTHawkeyeFloatingWidgetPlugin> plugin in self.plugins) {
            [self.cells addObject:[plugin widget]];
            if (![plugin widgetHidden])
                [self.visibleCells addObject:[plugin widget]];
        }
    }
}

- (void)rebuildDatasource {
    if ([[NSThread currentThread] isMainThread]) {
        [self buildCells];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self buildCells];
        });
    }
}

// MARK: -
- (void)receivedFlushStatusCommand {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        @synchronized(self.plugins) {
            for (id<MTHawkeyeFloatingWidgetPlugin> plugin in self.plugins) {
                if ([plugin respondsToSelector:@selector(receivedFlushStatusCommand)]) {
                    [plugin receivedFlushStatusCommand];
                }
            }
        }
    });
}

// MARK: -
- (void)addFloatingWidgetCell:(MTHMonitorViewCell *)cell {
    [self insertFloatingWidgetCell:cell atIndex:self.cells.count];
}

- (void)insertFloatingWidgetCell:(MTHMonitorViewCell *)cell atIndex:(NSInteger)index {
    @synchronized(self.cells) {
        [self.cells insertObject:cell atIndex:index];
        [self.visibleCells insertObject:cell atIndex:index];
    }
}

- (void)removeFloatingWidgetCell:(MTHMonitorViewCell *)cell {
    @synchronized(self.cells) {
        [self.cells removeObject:cell];
        [self.visibleCells removeObject:cell];
    }
}

- (void)hideFloatingWidgetCell:(MTHMonitorViewCell *)cell {
    @synchronized(self.visibleCells) {
        [self.visibleCells removeObject:cell];
    }
}

- (void)showFloatingWidgetCell:(MTHMonitorViewCell *)cell {
    @synchronized(self.visibleCells) {
        NSUInteger idx = [self.cells indexOfObject:cell];
        if (idx != NSUIntegerMax)
            [self.visibleCells insertObject:cell atIndex:idx];
    }
}

// MARK: - MTHawkeyeFloatingWidgetDelegate

- (void)floatingWidgetWantHidden:(id<MTHawkeyeFloatingWidgetPlugin>)widget {
    if ([[NSThread currentThread] isMainThread]) {
        [self hideWidget:widget];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideWidget:widget];
        });
    }
}

- (void)floatingWidgetWantShow:(id<MTHawkeyeFloatingWidgetPlugin>)widget {
    if ([[NSThread currentThread] isMainThread]) {
        [self showWidget:widget];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWidget:widget];
        });
    }
}

- (void)showWidget:(id<MTHawkeyeFloatingWidgetPlugin>)plugin {
    @synchronized(self.visibleCells) {
        if (![self.visibleCells containsObject:[plugin widget]]) {
            NSInteger idxMark = [self.plugins indexOfObject:plugin];
            __block NSInteger insertTo = 0;
            for (NSInteger i = 0; i < self.visibleCells.count && i < idxMark; ++i) {
                MTHMonitorViewCell *visibleCell = self.visibleCells[i];
                if ([self.cells containsObject:visibleCell])
                    insertTo++;
            }
            [self.visibleCells insertObject:[plugin widget] atIndex:insertTo];
        }
    }
    if ([self.delegate respondsToSelector:@selector(floatingWidgetsUpdated)]) {
        [self.delegate floatingWidgetsUpdated];
    }
}

- (void)hideWidget:(id<MTHawkeyeFloatingWidgetPlugin>)plugin {
    @synchronized(self.visibleCells) {
        [self.visibleCells removeObject:[plugin widget]];
    }
    if ([self.delegate respondsToSelector:@selector(floatingWidgetsUpdated)]) {
        [self.delegate floatingWidgetsUpdated];
    }
}

// MARK: - MTHawkeyeFloatingWidgetViewControllerDatasource

- (NSInteger)floatingWidgetCellCount {
    return self.visibleCells.count;
}

- (MTHMonitorViewCell *)floatingWidgetCellAtIndex:(NSUInteger)index {
    if (index < self.visibleCells.count)
        return [self.visibleCells objectAtIndex:index];
    else
        return nil;
}

@end
