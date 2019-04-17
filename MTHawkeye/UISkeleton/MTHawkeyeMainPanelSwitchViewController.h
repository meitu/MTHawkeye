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

@protocol MTHawkeyeMainPanelSwitcherDelegate;
@interface MTHawkeyeMainPanelSwitchViewController : UIViewController

@property (nonatomic, weak, readonly) id<MTHawkeyeMainPanelSwitcherDelegate> delegate;

- (instancetype)initWithSelectedIndexPath:(NSIndexPath *)selectedIndexPath
                                 delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate;

- (CGFloat)fullContentHeight;

@end


@protocol MTHawkeyeMainPanelSwitcherDelegate <NSObject>

@required
- (NSInteger)numberOfSwitcherOptionsSection;
- (NSInteger)numberOfSwitcherOptionsRowAtSection:(NSInteger)section;
- (NSString *)switcherOptionsSectionTitleAtIndex:(NSInteger)index;
- (NSString *)switcherOptionsTitleAtIndexPath:(NSIndexPath *)indexPath;

@optional
- (BOOL)shouldChangeSelectStatusToNew:(NSIndexPath *)newSelectIndexPath fromOld:(NSIndexPath *)oldSelectIndexPath;
- (void)panelSwitcherDidSelectAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
