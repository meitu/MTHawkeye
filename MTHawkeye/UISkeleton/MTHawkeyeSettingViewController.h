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


#import <UIKit/UIKit.h>
#import "MTHawkeyeSettingTableEntity.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHawkeyeSettingViewControllerDelegate;

@interface MTHawkeyeSettingViewController : UITableViewController

//- (instancetype)initWithDelegate:(id<MTHawkeyeSettingViewControllerDelegate>)delegate;

- (instancetype)initWithTitle:(NSString *)title
              viewModelEntity:(MTHawkeyeSettingTableEntity *)entity;

@end

@protocol MTHawkeyeSettingViewControllerDelegate <NSObject>

- (NSInteger)numberOfSettingPlugins;
- (MTHawkeyeSettingSectionEntity *)settingPluginAtSectionIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
