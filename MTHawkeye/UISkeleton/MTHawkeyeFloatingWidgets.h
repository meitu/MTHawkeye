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


#import <Foundation/Foundation.h>
#import "MTHawkeyeUIPlugin.h"

NS_ASSUME_NONNULL_BEGIN

@class MTHMonitorViewCell;
@protocol MTHawkeyeFloatingWidgetsDataDelegate;

@interface MTHawkeyeFloatingWidgets : NSObject

@property (nonatomic, weak) id<MTHawkeyeFloatingWidgetsDataDelegate> delegate;

@property (readonly) NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *plugins;


- (instancetype)initWithWidgets:(NSArray<id<MTHawkeyeFloatingWidgetPlugin>> *)widgets;

- (void)addWidget:(id<MTHawkeyeFloatingWidgetPlugin>)widget;
- (void)removeWidget:(id<MTHawkeyeFloatingWidgetPlugin>)widget;

- (nullable id<MTHawkeyeFloatingWidgetPlugin>)widgetFromID:(NSString *)widgetID;

- (void)rebuildDatasource;
- (void)receivedFlushStatusCommand;

- (NSInteger)floatingWidgetCellCount;
- (MTHMonitorViewCell *)floatingWidgetCellAtIndex:(NSUInteger)index;

@end

@protocol MTHawkeyeFloatingWidgetsDataDelegate <NSObject>

- (void)floatingWidgetsUpdated;

@end

NS_ASSUME_NONNULL_END
