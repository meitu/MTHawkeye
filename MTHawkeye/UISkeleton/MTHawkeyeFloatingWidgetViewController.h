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


#import <UIKit/UIKit.h>
#import "MTHFloatingMonitorWindow.h"
#import "MTHawkeyeFloatingWidgets.h"

NS_ASSUME_NONNULL_BEGIN

@class MTHMonitorViewConfiguration;
@class MTHMonitorViewCell;
@protocol MTHawkeyeFloatingWidgetViewControllerDatasource;
@protocol MTHawkeyeFloatingWidgetViewControllerDelegate;


@interface MTHawkeyeFloatingWidgetViewController : UIViewController <MTHFloatingMonitorWindowDelegate, MTHawkeyeFloatingWidgetsDataDelegate>

@property (nonatomic, weak) id<MTHawkeyeFloatingWidgetViewControllerDatasource> datasource;
@property (nonatomic, weak) id<MTHawkeyeFloatingWidgetViewControllerDelegate> delegate;

- (instancetype)init;

- (void)reloadData;

@end


@protocol MTHawkeyeFloatingWidgetViewControllerDatasource <NSObject>

@required
- (NSInteger)floatingWidgetCellCount;
- (MTHMonitorViewCell *)floatingWidgetCellAtIndex:(NSUInteger)index;

@end

@protocol MTHawkeyeFloatingWidgetViewControllerDelegate <NSObject>

- (void)floatingWidgetDidTapped;

@end

NS_ASSUME_NONNULL_END
