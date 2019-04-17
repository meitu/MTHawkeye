//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 09/11/2017
// Created by: EuanC
//


#import <UIKit/UIKit.h>

@class MTHCallTraceTimeCostModel;
@class MTHTimeIntervalCustomEventRecord;
@class MTHViewControllerAppearRecord;

@interface MTHTimeProfilerResultViewSection : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSTimeInterval timeCostInMS;
@property (nonatomic, strong) MTHViewControllerAppearRecord *vcRecord;
@property (nonatomic, copy) NSArray *cellModels; /**< could be MTHCallTraceTimeCostModel or MTHTimeIntervalCustomEventRecord */

@end


@interface MTHUITimeProfilerResultViewModel : NSObject

- (instancetype)initWithVCAppearRecords:(NSArray<MTHViewControllerAppearRecord *> *)vcAppearRecords
                      detailCostRecords:(NSArray<MTHCallTraceTimeCostModel *> *)detailCostRecords
                     customEventRecords:(NSArray<MTHTimeIntervalCustomEventRecord *> *)customEventRecords;

- (NSInteger)numberOfSection;
- (NSString *)titleForSection:(NSInteger)section;
- (NSTimeInterval)timeCostInMSForSection:(NSInteger)section;
- (MTHTimeProfilerResultViewSection *)sectionAtIndex:(NSInteger)index;
- (MTHViewControllerAppearRecord *)vcRecordForSection:(NSInteger)section;
- (NSInteger)numberOfCellForSection:(NSInteger)section;

- (id)cellModelAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)cellModelsForSection:(NSUInteger)section;

- (NSArray *)cellModelsFor:(MTHViewControllerAppearRecord *)vcAppearRecord atSection:(NSUInteger)section;
- (NSArray *)extraRecordsStartFrom:(NSTimeInterval)startTime endBefore:(NSTimeInterval)endTime lowerSectionIndex:(NSUInteger)section;

- (void)updateCell:(NSIndexPath *)indexPath expanded:(bool)expanded;
- (BOOL)cellExpandedForIndexPath:(NSIndexPath *)indexPath;

@end
