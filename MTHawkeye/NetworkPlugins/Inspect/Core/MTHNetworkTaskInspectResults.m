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


#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspection.h"


@interface MTHNetworkTaskInspectionWithResult ()

@property (nonatomic, copy, readwrite) NSArray<MTHNetworkTaskAdvice *> *advices;

- (instancetype)initWithInspection:(MTHNetworkTaskInspection *)inspection;

- (void)addAdvice:(MTHNetworkTaskAdvice *)advice;
- (void)addAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices;

@end


@interface MTHNetworkTaskInspectionsGroup ()

@property (nonatomic, copy, readwrite) NSArray<MTHNetworkTaskInspectionWithResult *> *inspections;

- (void)updateInspections:(MTHNetworkTaskInspectionWithResult *)advices;

@end


@interface MTHNetworkTaskInspectResults ()

@property (nonatomic, copy, readwrite) NSArray<MTHNetworkTaskInspectionsGroup *> *groups;

@end


@implementation MTHNetworkTaskInspectResults

- (void)updateGroupsInfoWithInspections:(NSArray<MTHNetworkTaskInspection *> *)inspections {
    NSMutableArray<MTHNetworkTaskInspectionsGroup *> *mutableGroups = self.groups ? [self.groups mutableCopy] : [NSMutableArray array];
    for (MTHNetworkTaskInspection *inspection in inspections) {
        MTHNetworkTaskInspectionsGroup *group = nil;
        for (MTHNetworkTaskInspectionsGroup *item in mutableGroups) {
            if ([item.name isEqualToString:inspection.group]) {
                group = item;
                break;
            }
        }

        if (group == nil) {
            group = [[MTHNetworkTaskInspectionsGroup alloc] init];
            group.name = inspection.group;
            [mutableGroups addObject:group];
        }

        MTHNetworkTaskInspectionWithResult *advices = nil;
        for (MTHNetworkTaskInspectionWithResult *item in group.inspections) {
            if ([item.name isEqualToString:inspection.name]) {
                advices = item;
                break;
            }
        }

        if (advices == nil) {
            advices = [[MTHNetworkTaskInspectionWithResult alloc] initWithInspection:inspection];
            [group updateInspections:advices];
        }
    }
    self.groups = [mutableGroups copy];
}

- (void)updateResultsAsInspection:(MTHNetworkTaskInspection *)inspection inspectedAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices {
    for (MTHNetworkTaskInspectionsGroup *group in self.groups) {
        if ([group.name isEqualToString:inspection.group]) {
            for (MTHNetworkTaskInspectionWithResult *inspectionsWithResult in group.inspections) {
                if ([inspectionsWithResult.name isEqualToString:inspection.name]) {
                    [inspectionsWithResult addAdvices:advices];
                }
            }
        }
    }
}

- (void)updateInspectedAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices groupName:(NSString *)groupId typeName:(NSString *)name {


    for (MTHNetworkTaskInspectionsGroup *group in self.groups) {
        if ([group.name isEqualToString:groupId]) {
            for (MTHNetworkTaskInspectionWithResult *inspectionsWithResult in group.inspections) {
                if ([inspectionsWithResult.name isEqualToString:name]) {
                    [inspectionsWithResult addAdvices:advices];
                }
            }
        }
    }
}
@end


// MARK: -

@implementation MTHNetworkTaskInspectionsGroup

- (void)updateInspections:(MTHNetworkTaskInspectionWithResult *)adviceInfo {
    if (!adviceInfo) {
        return;
    }
    NSMutableArray *tmp = self.inspections ? [self.inspections mutableCopy] : [NSMutableArray array];
    [tmp addObject:adviceInfo];
    self.inspections = [tmp copy];
}

@end


// MARK: -

@implementation MTHNetworkTaskInspectionWithResult

- (instancetype)initWithInspection:(MTHNetworkTaskInspection *)inspection {
    if ((self = [super init])) {
        _inspection = inspection;
        _name = inspection.name;
    }
    return self;
}

- (void)addAdvice:(MTHNetworkTaskAdvice *)advice {
    [self addAdvices:@[ advice ]];
}

- (void)addAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices {
    if (!advices || advices.count == 0) {
        return;
    }
    NSMutableArray *tmp = self.advices ? [self.advices mutableCopy] : [NSMutableArray array];
    [tmp addObjectsFromArray:advices];
    [tmp sortUsingComparator:^NSComparisonResult(MTHNetworkTaskAdvice *obj1, MTHNetworkTaskAdvice *obj2) {
        return obj1.requestIndex < obj2.requestIndex;
    }];
    self.advices = [tmp copy];
}

@end
