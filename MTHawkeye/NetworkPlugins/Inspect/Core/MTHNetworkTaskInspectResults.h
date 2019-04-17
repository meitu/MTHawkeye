//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 08/09/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTaskAdvice;
@class MTHNetworkTaskInspectionsGroup;
@class MTHNetworkTaskInspectionWithResult;
@class MTHNetworkTaskInspection;


@interface MTHNetworkTaskInspectResults : NSObject

@property (nonatomic, copy, readonly) NSArray<MTHNetworkTaskInspectionsGroup *> *groups;

- (void)updateGroupsInfoWithInspections:(NSArray<MTHNetworkTaskInspection *> *)inspections;

- (void)updateResultsAsInspection:(MTHNetworkTaskInspection *)inspection inspectedAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices;
- (void)updateInspectedAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices groupName:(NSString *)groupId typeName:(NSString *)name;

@end



@interface MTHNetworkTaskInspectionsGroup : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, readonly) NSArray<MTHNetworkTaskInspectionWithResult *> *inspections;

@end



@interface MTHNetworkTaskInspectionWithResult : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) MTHNetworkTaskInspection *inspection;
@property (nonatomic, copy, readonly) NSArray<MTHNetworkTaskAdvice *> *advices;

@end

NS_ASSUME_NONNULL_END
