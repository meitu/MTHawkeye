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


#import "MTHUITimeProfilerResultViewModel.h"
#import "MTHCallTraceTimeCostModel.h"
#import "MTHTimeIntervalRecorder.h"
#import "MTHawkeyeUtility.h"

@interface MTHTimeProfilerResultViewSection () {
  @public
    bool *expandedStatus;
}

@end

@implementation MTHTimeProfilerResultViewSection

- (void)dealloc {
    if (expandedStatus) {
        free(expandedStatus);
        expandedStatus = nil;
    }
}

- (NSString *)description {
    NSMutableString *str = [NSMutableString new];
    if (_vcRecord) {
        [str appendFormat:@"    %-8sms| %@\n", [[NSString stringWithFormat:@"%6.2f", [_vcRecord appearCostInMS]] UTF8String], [_vcRecord description]];
    } else {
        [str appendFormat:@"    %-8sms| %@\n", [[NSString stringWithFormat:@"%6.2f", _timeCostInMS] UTF8String], _title];
    }

    return [str copy];
}

- (void)setCellModels:(NSArray<MTHCallTraceTimeCostModel *> *)models {
    _cellModels = models;

    if (expandedStatus != nil) {
        free(expandedStatus);
        expandedStatus = nil;
    }

    expandedStatus = (bool *)malloc(sizeof(bool) * models.count);
    memset(expandedStatus, false, sizeof(bool) * models.count);
}

@end


/****************************************************************************/
#pragma mark -


@interface MTHUITimeProfilerResultViewModel ()

@property (nonatomic, copy) NSArray<MTHTimeProfilerResultViewSection *> *sections;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation MTHUITimeProfilerResultViewModel


- (instancetype)initWithVCAppearRecords:(NSArray<MTHViewControllerAppearRecord *> *)vcAppearRecords
                      detailCostRecords:(NSArray<MTHCallTraceTimeCostModel *> *)detailCostRecords
                     customEventRecords:(NSArray<MTHTimeIntervalCustomEventRecord *> *)customEventRecords {
    if ((self = [super init])) {
        [self setupWithVCAppearRecords:vcAppearRecords detailCostRecords:detailCostRecords customEventRecords:customEventRecords];
    }
    return self;
}

- (void)setupWithVCAppearRecords:(NSArray<MTHViewControllerAppearRecord *> *)vcAppearedRecords
               detailCostRecords:(NSArray<MTHCallTraceTimeCostModel *> *)detailCostRecords
              customEventRecords:(NSArray<MTHTimeIntervalCustomEventRecord *> *)customEventRecords {

    NSInteger cacheDetailCallRecordsIndex = 0;
    NSInteger cacheCustomEventRecordsIndex = 0;
    NSMutableArray *sections = [NSMutableArray array];

    [sections addObject:[self appLaunchedSection]];

    MTHTimeProfilerResultViewSection *initializerSection = [self initializerSection];
    if (initializerSection)
        [sections addObject:initializerSection];

    for (NSInteger iRecord = 0;
         iRecord < vcAppearedRecords.count || cacheDetailCallRecordsIndex < detailCostRecords.count || cacheCustomEventRecordsIndex < customEventRecords.count;
         ++iRecord) {

        MTHViewControllerAppearRecord *vcAppearedRecord = nil;
        if (iRecord < vcAppearedRecords.count) {
            vcAppearedRecord = vcAppearedRecords[iRecord];
        }

        MTHTimeProfilerResultViewSection *section = [[MTHTimeProfilerResultViewSection alloc] init];
        section.vcRecord = vcAppearedRecord;
        [sections addObject:section];

        // section title
        if (iRecord < vcAppearedRecords.count) {
            NSTimeInterval vcLoadCost = [vcAppearedRecord appearCostInMS];
            if (vcLoadCost == 0.f) {
                section.title = [NSString stringWithFormat:@"%@", vcAppearedRecord.className];
            } else {
                section.title = vcAppearedRecord.className;
                section.timeCostInMS = vcLoadCost;
            }

            if (iRecord == 0) {
                // cost from +load to first view controller appeared
                MTHTimeProfilerResultViewSection *afterInitializerCostToFirstVC = [self appInitializerToFirstVCCostSection:vcAppearedRecord];
                if (afterInitializerCostToFirstVC)
                    [sections addObject:afterInitializerCostToFirstVC];

                // total cost (startup ~ initializer ~ first view did appear)
                MTHTimeProfilerResultViewSection *launchCostSection = [self appLaunchToFirstVCCostSection:vcAppearedRecord];
                [sections addObject:launchCostSection];
            }
        } else {
            section.title = [NSString stringWithFormat:@"↑ %@ (Now)", [self.dateFormatter stringFromDate:[NSDate date]]];
        }

        NSTimeInterval sentryTime;
        if (vcAppearedRecord) {
            sentryTime = vcAppearedRecord.viewDidAppearExitTime;
        } else {
            // after the
            sentryTime = [MTHawkeyeUtility currentTime];
        }

        NSArray *cellModels = [self extractEventsBeforeTime:sentryTime
                                          detailCostRecords:detailCostRecords
                                 detailCostRecordsFromIndex:&cacheDetailCallRecordsIndex
                                         customEventRecords:customEventRecords
                                customEventRecordsFromIndex:&cacheCustomEventRecordsIndex];
        if (cellModels.count > 0) {
            section.cellModels = cellModels;
        }
    }

    self.sections = [[sections reverseObjectEnumerator] allObjects];
}

- (MTHTimeProfilerResultViewSection *)appLaunchedSection {
    MTHTimeProfilerResultViewSection *launchSection = [[MTHTimeProfilerResultViewSection alloc] init];
    NSDate *launchDate = [NSDate dateWithTimeIntervalSince1970:[MTHawkeyeUtility appLaunchedTime]];
    launchSection.title = [NSString stringWithFormat:@"🏃 App Launched At %@", [self.dateFormatter stringFromDate:launchDate]];
    return launchSection;
}

- (MTHTimeProfilerResultViewSection *)initializerSection {
    if ([MTHTimeIntervalRecorder shared].launchRecord.firstObjcLoadStartTime <= 0.f)
        return nil;

    MTHTimeProfilerResultViewSection *initializerSection = [[MTHTimeProfilerResultViewSection alloc] init];
    initializerSection.title = [NSString stringWithFormat:@"⤒ Before Initializer (First +load)"];
    initializerSection.timeCostInMS = ([MTHTimeIntervalRecorder shared].launchRecord.firstObjcLoadStartTime - [MTHTimeIntervalRecorder shared].launchRecord.appLaunchTime) * 1000.f;
    return initializerSection;
}

- (MTHTimeProfilerResultViewSection *)appInitializerToFirstVCCostSection:(MTHViewControllerAppearRecord *)firstVCAppearRecord {
    if ([MTHTimeIntervalRecorder shared].launchRecord.firstObjcLoadStartTime <= 0.f)
        return nil;

    NSTimeInterval afterInitializerCost = (firstVCAppearRecord.viewDidAppearExitTime - [MTHTimeIntervalRecorder shared].launchRecord.firstObjcLoadStartTime) * 1000.f;
    MTHTimeProfilerResultViewSection *afterInitializerSection = [[MTHTimeProfilerResultViewSection alloc] init];
    afterInitializerSection.title = @"🚀 Warm start (Initializer ~ 1st VC Appeared)";
    afterInitializerSection.timeCostInMS = afterInitializerCost;
    return afterInitializerSection;
}

- (MTHTimeProfilerResultViewSection *)appLaunchToFirstVCCostSection:(MTHViewControllerAppearRecord *)firstVCAppearRecord {
    MTHTimeProfilerResultViewSection *launchSection = [[MTHTimeProfilerResultViewSection alloc] init];
    NSTimeInterval startupTotalCost = (firstVCAppearRecord.viewDidAppearExitTime - [MTHawkeyeUtility appLaunchedTime]) * 1000.f;
    launchSection.title = @"🚀 App Launch time";
    launchSection.timeCostInMS = startupTotalCost;
    return launchSection;
}

- (NSArray *)extractEventsBeforeTime:(NSTimeInterval)sentryTime
                   detailCostRecords:(NSArray<MTHCallTraceTimeCostModel *> *)detailCostRecords
          detailCostRecordsFromIndex:(NSInteger *)cacheDetailCostIndex
                  customEventRecords:(NSArray<MTHTimeIntervalCustomEventRecord *> *)customEventRecords
         customEventRecordsFromIndex:(NSInteger *)cacheCustomEventIndex {

    NSMutableArray *cellModels = [NSMutableArray array];
    for (NSInteger iDetail = *cacheDetailCostIndex, iEvent = *cacheCustomEventIndex; iDetail < detailCostRecords.count || iEvent < customEventRecords.count;) {
        MTHCallTraceTimeCostModel *calltraceRecord = nil;
        MTHTimeIntervalCustomEventRecord *eventRecord = nil;
        if (iDetail < detailCostRecords.count)
            calltraceRecord = detailCostRecords[iDetail];
        if (iEvent < customEventRecords.count)
            eventRecord = customEventRecords[iEvent];

        BOOL willCheckCalltraceRecord = NO;
        BOOL willCheckEventRecord = NO;
        if (calltraceRecord && eventRecord) {
            if (calltraceRecord.eventTime < eventRecord.timeStamp)
                willCheckCalltraceRecord = YES;
            else
                willCheckEventRecord = YES;
        } else if (calltraceRecord) {
            willCheckCalltraceRecord = YES;
        } else if (eventRecord) {
            willCheckEventRecord = YES;
        }

        BOOL shouldInsertCallTrace = NO;
        BOOL shouldInsertCustomEvent = NO;
        if (willCheckCalltraceRecord && calltraceRecord.eventTime < sentryTime) {
            shouldInsertCallTrace = YES;
        } else if (willCheckEventRecord && eventRecord.timeStamp < sentryTime) {
            shouldInsertCustomEvent = YES;
        }

        if (shouldInsertCallTrace) {
            [cellModels insertObject:calltraceRecord atIndex:0];
            iDetail++;
            *cacheDetailCostIndex = iDetail;
        } else if (shouldInsertCustomEvent) {
            [cellModels insertObject:eventRecord atIndex:0];
            iEvent++;
            *cacheCustomEventIndex = iEvent;
        } else {
            break;
        }
    }
    return [cellModels copy];
}

// MARK: -
- (NSInteger)numberOfSection {
    return self.sections.count;
}

- (NSString *)titleForSection:(NSInteger)section {
    return self.sections[section].title;
}

- (NSTimeInterval)timeCostInMSForSection:(NSInteger)section {
    return self.sections[section].timeCostInMS;
}

- (MTHTimeProfilerResultViewSection *)sectionAtIndex:(NSInteger)index {
    return self.sections[index];
}

- (MTHViewControllerAppearRecord *)vcRecordForSection:(NSInteger)section {
    return self.sections[section].vcRecord;
}

- (NSInteger)numberOfCellForSection:(NSInteger)section {
    return self.sections[section].cellModels.count;
}

- (id)cellModelAtIndexPath:(NSIndexPath *)indexPath {
    return self.sections[indexPath.section].cellModels[indexPath.row];
}

- (NSArray *)cellModelsForSection:(NSUInteger)section {
    return self.sections[section].cellModels;
}

- (NSArray *)cellModelsFor:(MTHViewControllerAppearRecord *)record atSection:(NSUInteger)section {
    // only case cells round the VC start.
    NSTimeInterval startFrom = 0, endBefore = 0;
    if (record.initExitTime > 0.f)
        startFrom = record.initExitTime - 2.f;
    else if (record.viewDidLoadEnterTime > 0.f)
        startFrom = record.viewDidLoadEnterTime - 2.f;
    else if (record.viewWillAppearEnterTime > 0.f)
        startFrom = record.viewWillAppearEnterTime - 2.f;

    endBefore = record.viewDidAppearExitTime;
    return [self extraRecordsStartFrom:startFrom endBefore:endBefore lowerSectionIndex:section];
}

- (NSArray *)extraRecordsStartFrom:(NSTimeInterval)startFrom endBefore:(NSTimeInterval)endBefore lowerSectionIndex:(NSUInteger)sectionIdx {
    if (sectionIdx >= self.sections.count)
        return nil;

    NSMutableArray *resultRecords = @[].mutableCopy;
    NSInteger index = sectionIdx;

    // sections are order by time descending
    while (index < self.sections.count) {
        MTHTimeProfilerResultViewSection *section = self.sections[index];
        index++;

        if (section.cellModels.count == 0)
            continue;

        __block NSTimeInterval sectionMin = 0;
        NSMutableArray *matchedRecordsAtIndex = section.cellModels ? [section.cellModels mutableCopy] : @[].mutableCopy;
        NSIndexSet *indexSetToAdd = [matchedRecordsAtIndex indexesOfObjectsPassingTest:^BOOL(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            NSTimeInterval modelTime = 0;
            if ([obj isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
                modelTime = [(MTHTimeIntervalCustomEventRecord *)obj timeStamp];
            } else if ([obj isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
                modelTime = [(MTHCallTraceTimeCostModel *)obj eventTime];
            }
            if (modelTime < sectionMin) sectionMin = modelTime;

            return (modelTime > startFrom && modelTime < endBefore) ? YES : NO;
        }];

        if (sectionMin > 0 && sectionMin < startFrom)
            break;

        NSArray *matchedRecords = [matchedRecordsAtIndex objectsAtIndexes:indexSetToAdd];
        if (matchedRecords.count > 0)
            [resultRecords addObjectsFromArray:matchedRecords];
    }

    [resultRecords sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSTimeInterval recordTime1 = 0;
        if ([obj1 isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
            recordTime1 = [(MTHTimeIntervalCustomEventRecord *)obj1 timeStamp];
        } else if ([obj1 isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
            recordTime1 = [(MTHCallTraceTimeCostModel *)obj1 eventTime];
        }
        NSTimeInterval recordTime2 = 0;
        if ([obj2 isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
            recordTime2 = [(MTHTimeIntervalCustomEventRecord *)obj2 timeStamp];
        } else if ([obj2 isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
            recordTime2 = [(MTHCallTraceTimeCostModel *)obj2 eventTime];
        }
        return recordTime1 > recordTime2 ? NSOrderedDescending : NSOrderedAscending;
    }];
    return [resultRecords copy];
}

- (void)updateCell:(NSIndexPath *)indexPath expanded:(bool)expanded {
    MTHTimeProfilerResultViewSection *section = self.sections[indexPath.section];
    section->expandedStatus[indexPath.row] = expanded;
}

- (BOOL)cellExpandedForIndexPath:(NSIndexPath *)indexPath {
    MTHTimeProfilerResultViewSection *section = self.sections[indexPath.section];
    return section->expandedStatus[indexPath.row];
}

// MARK: - helper
- (NSDateFormatter *)dateFormatter {
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"HH:mm:ss. SSS"];
        [_dateFormatter setLocale:[NSLocale currentLocale]];
    }
    return _dateFormatter;
}

@end
