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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHawkeyeSettingSectionEntity;
@class MTHawkeyeSettingCellEntity;

@interface MTHawkeyeSettingTableEntity : NSObject

@property (nonatomic, copy) NSArray<MTHawkeyeSettingSectionEntity *> *sections;

@end

@interface MTHawkeyeSettingSectionEntity : NSObject

@property (nonatomic, copy, nullable) NSString *headerText;
@property (nonatomic, copy, nullable) NSString *footerText;
@property (nonatomic, copy) NSArray<MTHawkeyeSettingCellEntity *> *cells;
@property (nonatomic, copy, nullable) NSString *tag;

- (void)addCell:(MTHawkeyeSettingCellEntity *)cell;
- (void)insertCell:(MTHawkeyeSettingCellEntity *)cell atIndex:(NSUInteger)index;
- (void)removeCellByTag:(NSString *)cellTag;

@end


/****************************************************************************/
#pragma mark - Setting Cell

@protocol MTHawkeyeSettingCellEntityDelegate;
@interface MTHawkeyeSettingCellEntity : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *tag;
@property (nonatomic, assign) BOOL frozen;

@property (nonatomic, weak, nullable) id<MTHawkeyeSettingCellEntityDelegate> delegate;

@end

@protocol MTHawkeyeSettingCellEntityDelegate <NSObject>

- (void)hawkeyeSettingEntityValueDidChanged:(MTHawkeyeSettingCellEntity *)entity;

@end


// MARK: -
@interface MTHawkeyeSettingFoldedCellEntity : MTHawkeyeSettingCellEntity

@property (nonatomic, copy) NSString *foldedTitle;
@property (nonatomic, copy) NSArray<MTHawkeyeSettingSectionEntity *> *foldedSections;

- (void)addSection:(MTHawkeyeSettingSectionEntity *)section;
- (void)insertSection:(MTHawkeyeSettingSectionEntity *)section atIndex:(NSUInteger)insertTo;
- (void)insertCell:(MTHawkeyeSettingCellEntity *)cell atIndexPath:(NSIndexPath *)insertTo;

@end


@interface MTHawkeyeSettingEditorCellEntity : MTHawkeyeSettingCellEntity

@property (nonatomic, assign) UIKeyboardType editorKeyboardType;
@property (nonatomic, copy, nullable) NSString *valueUnits;
@property (nonatomic, copy, nullable) NSString *inputTips;

@property (nonatomic, copy) NSString * (^setupValueHandler)(void);
@property (nonatomic, copy) BOOL (^valueChangedHandler)(NSString *newValue);

@end


@interface MTHawkeyeSettingSwitcherCellEntity : MTHawkeyeSettingCellEntity

@property (nonatomic, copy) BOOL (^setupValueHandler)(void);
@property (nonatomic, copy) BOOL (^valueChangedHandler)(BOOL newValue);

@end


@interface MTHawkeyeSettingSelectorCellEntity : MTHawkeyeSettingCellEntity

@property (nonatomic, copy) NSArray<NSString *> *options;
@property (nonatomic, copy) NSUInteger (^setupSelectedIndexHandler)(void);
@property (nonatomic, copy) BOOL (^selectIndexChangedHandler)(NSUInteger newIndex);

@end


@interface MTHawkeyeSettingActionCellEntity : MTHawkeyeSettingCellEntity

@property (nonatomic, copy) void (^didTappedHandler)(void);

@end

NS_ASSUME_NONNULL_END
