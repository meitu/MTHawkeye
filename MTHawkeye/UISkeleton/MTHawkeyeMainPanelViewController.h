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


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTHawkeyeMainPanelViewControllerDatasource;
@protocol MTHawkeyeMainPanelSwitcherDelegate;

@interface MTHawkeyeMainPanelViewController : UIViewController

@property (nonatomic, weak) id<MTHawkeyeMainPanelViewControllerDatasource> datasource;
@property (nonatomic, weak) id<MTHawkeyeMainPanelSwitcherDelegate> delegate;

- (instancetype)initWithSelectedIndexPath:(NSIndexPath *)indexPath
                               datasource:(id<MTHawkeyeMainPanelViewControllerDatasource>)datasource
                                 delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate;

- (instancetype)initWithSelectedPanelID:(NSString *)panelID
                             datasource:(id<MTHawkeyeMainPanelViewControllerDatasource>)datasource
                               delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate;

@end


@protocol MTHawkeyeMainPanelViewControllerDatasource <NSObject>

@optional
- (NSIndexPath *)indexPathForPanelID:(NSString *)panelID;
- (NSString *)panelViewControllerTitleForSwitcherOptionAtIndexPath:(NSIndexPath *)indexPath;
- (UIViewController *)panelViewControllerForSwitcherOptionAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
