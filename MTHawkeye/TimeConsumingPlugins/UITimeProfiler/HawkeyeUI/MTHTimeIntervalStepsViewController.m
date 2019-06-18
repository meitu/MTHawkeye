//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/20
// Created by: 潘名扬
//


#import "MTHTimeIntervalStepsViewController.h"
#import "MTHCallTrace.h"
#import "MTHCallTraceTimeCostModel.h"
#import "MTHTimeIntervalRecorder.h"
#import "MTHTimeIntervalStepsViewCell.h"
#import "MTHUITImeProfilerResultEventCell.h"
#import "MTHUITimeProfilerResultCallTraceCell.h"
#import "MTHawkeyeUtility.h"

static NSString *const kReuseIdentifier = @"MTHCallTraceVCDetailCell";
//static CGFloat const kPreferContentWidth = 300.f;
//static CGFloat const kPreferContentHeight = 480.f;
static CGFloat const kDurationLabelHeight = 40.f;


#pragma mark - MTHTimeIntervalSelectionViewController

@interface MTHTimeIntervalStepsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) MTHAppLaunchRecord *launchRecord;
@property (nonatomic, strong) MTHViewControllerAppearRecord *vcRecord;

@property (nonatomic, copy) NSArray<MTHTimeIntervalStepsViewCellModel *> *cellModels;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) NSUInteger currentSelectedRow;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *durationLabel;

@end

@implementation MTHTimeIntervalStepsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.allowsMultipleSelection = YES;
    tableView.contentInset = UIEdgeInsetsMake(0, 0, kDurationLabelHeight, 0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, kDurationLabelHeight, 0);
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [tableView registerClass:MTHUITimeProfilerResultCallTraceCell.class forCellReuseIdentifier:NSStringFromClass(MTHUITimeProfilerResultCallTraceCell.class)];
    [tableView registerClass:MTHUITImeProfilerResultEventCell.class forCellReuseIdentifier:NSStringFromClass(MTHUITImeProfilerResultEventCell.class)];
    [self.view addSubview:tableView];
    self.tableView = tableView;

    CGRect durationFrame = CGRectMake(0, CGRectGetHeight(self.view.bounds) - kDurationLabelHeight, CGRectGetWidth(self.view.bounds), kDurationLabelHeight);

    UIView *durationView = [[UIView alloc] initWithFrame:durationFrame];
    durationView.backgroundColor = [UIColor darkGrayColor];
    durationView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UILabel *durationLabel = [[UILabel alloc] initWithFrame:durationView.bounds];
    durationLabel.text = @"Please select a time range";
    durationLabel.textColor = [UIColor whiteColor];
    durationLabel.font = [UIFont systemFontOfSize:12];
    durationLabel.textAlignment = NSTextAlignmentCenter;
    durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [durationView addSubview:durationLabel];

    [self.view addSubview:durationView];
    self.durationLabel = durationLabel;

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateFormat = @"mm:ss.SSS";
    self.dateFormatter.timeZone = [NSTimeZone localTimeZone];

    self.currentSelectedRow = NSNotFound;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(rightBarItemAction)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)setupWithAppLaunchRecord:(MTHAppLaunchRecord *)launchRecord firstVCRecord:(nullable MTHViewControllerAppearRecord *)vcRecord extraRecords:(nullable NSArray *)extraRecords {
    self.launchRecord = launchRecord;
    self.vcRecord = vcRecord;
    self.title = @"App Launch Cost";

    NSMutableArray<MTHTimeIntervalStepsViewCellModel *> *cellModels = @[].mutableCopy;
    [cellModels addObjectsFromArray:[self stepsCellModelFromLaunchRecord:launchRecord]];
    [cellModels addObjectsFromArray:[self stepsCellModelFromVCRecord:vcRecord trimZeroTimestamp:YES]];
    [cellModels addObjectsFromArray:[self stepsCellModelFromExtraRecords:extraRecords]];

    NSSortDescriptor *sortTimeStampDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(timeStamp)) ascending:YES];
    [cellModels sortUsingDescriptors:@[ sortTimeStampDescriptor ]];

    self.cellModels = cellModels.copy;
}

- (void)setupWithVCRecord:(MTHViewControllerAppearRecord *)vcRecord extraRecords:(nullable NSArray *)extraRecords {
    self.vcRecord = vcRecord;
    self.title = vcRecord.className;

    NSMutableArray<MTHTimeIntervalStepsViewCellModel *> *cellModels = @[].mutableCopy;
    [cellModels addObjectsFromArray:[self stepsCellModelFromVCRecord:vcRecord trimZeroTimestamp:NO]];
    [cellModels addObjectsFromArray:[self stepsCellModelFromExtraRecords:extraRecords]];

    NSSortDescriptor *sortTimeStampDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(timeStamp)) ascending:YES];
    [cellModels sortUsingDescriptors:@[ sortTimeStampDescriptor ]];

    self.cellModels = cellModels.copy;
}

// MAKR: -
- (NSArray<MTHTimeIntervalStepsViewCellModel *> *)stepsCellModelFromLaunchRecord:(MTHAppLaunchRecord *)launchRecord {
    NSMutableArray<MTHTimeIntervalStepsViewCellModel *> *result = @[].mutableCopy;
    for (MTHAppLaunchStep step = 0; step < MTHAppLaunchStepUnknown; step++) {
        NSTimeInterval time = [launchRecord timeStampOfStep:step];
        if (time <= 0.f)
            continue;

        MTHTimeIntervalStepsViewCellModel *cellModel = [[MTHTimeIntervalStepsViewCellModel alloc] init];
        cellModel.timeStamp = [launchRecord timeStampOfStep:step];
        cellModel.timeStampTitle = [MTHAppLaunchRecord displayNameOfStep:step];
        [result addObject:cellModel];
    }
    return [result copy];
}

- (NSArray<MTHTimeIntervalStepsViewCellModel *> *)stepsCellModelFromVCRecord:(nullable MTHViewControllerAppearRecord *)vcRecord trimZeroTimestamp:(BOOL)trimZeroTimestamp {
    if (vcRecord == nil)
        return @[];

    NSMutableArray<MTHTimeIntervalStepsViewCellModel *> *result = @[].mutableCopy;
    for (MTHViewControllerLifeCycleStep step = 0; step < MTHViewControllerLifeCycleStepUnknown; step++) {
        NSTimeInterval stepTimeStamp = [vcRecord timeStampOfStep:step];
        if (stepTimeStamp <= 0.f && trimZeroTimestamp)
            continue;

        MTHTimeIntervalStepsViewCellModel *cellModel = [[MTHTimeIntervalStepsViewCellModel alloc] init];
        cellModel.timeStamp = stepTimeStamp;
        cellModel.timeStampTitle = [MTHViewControllerAppearRecord displayNameOfStep:step];
        [result addObject:cellModel];
    }
    return [result copy];
}

- (NSArray<MTHTimeIntervalStepsViewCellModel *> *)stepsCellModelFromExtraRecords:(nullable NSArray *)extraRecords {
    NSMutableArray<MTHTimeIntervalStepsViewCellModel *> *result = @[].mutableCopy;
    for (NSInteger i = 0; i < extraRecords.count; i++) {
        id extraRecord = extraRecords[i];
        if ([extraRecord isKindOfClass:[MTHCallTraceTimeCostModel class]]) {
            MTHCallTraceTimeCostModel *calltraceRecord = (MTHCallTraceTimeCostModel *)extraRecord;
            MTHTimeIntervalStepsViewCellModel *cellModel = [[MTHTimeIntervalStepsViewCellModel alloc] init];
            cellModel.timeStamp = calltraceRecord.eventTime;
            cellModel.timeCostModel = calltraceRecord;
            [result addObject:cellModel];
        } else if ([extraRecord isKindOfClass:[MTHTimeIntervalCustomEventRecord class]]) {
            MTHTimeIntervalCustomEventRecord *customRecord = (MTHTimeIntervalCustomEventRecord *)extraRecord;
            MTHTimeIntervalStepsViewCellModel *cellModel = [[MTHTimeIntervalStepsViewCellModel alloc] init];
            cellModel.timeStamp = customRecord.timeStamp;
            cellModel.customEvent = customRecord;
            [result addObject:cellModel];
        }
    }
    return [result copy];
}

// MARK: -
- (void)rightBarItemAction {
    NSString *calltraceDesc;
    if ([MTHCallTrace isRunning]) {
        double timethreshold = [MTHCallTrace currentTraceTimeThreshold];
        int maxDepth = [MTHCallTrace currentTraceMaxDepth];
        calltraceDesc = [NSString stringWithFormat:@"objc calltrace time_thresolt: %.0fms, max_depth: %d", timethreshold, maxDepth];
    } else {
        calltraceDesc = @" Objective CallTrace off.";
    }

    __weak __typeof(NSDateFormatter *) dateFormatter = [self dateFormatter];
    NSMutableString *logString = [NSMutableString stringWithFormat:@"\n\n[hawkeye][ui-time-profiler] %@\n\n", calltraceDesc];
    [self.cellModels enumerateObjectsUsingBlock:^(MTHTimeIntervalStepsViewCellModel *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if (obj.timeCostModel) {
            [logString appendFormat:@"%s\n", [[obj.timeCostModel description] UTF8String]];
        } else if (obj.customEvent) {
            [logString appendFormat:@"%s\n", [[obj.customEvent description] UTF8String]];
        } else {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:obj.timeStamp];
            [logString appendFormat:@"%12s || %@\n", [[dateFormatter stringFromDate:date] UTF8String], obj.timeStampTitle];
        }
    }];
    [logString appendString:@"\n\n"];

#ifdef DEBUG
    printf("%s", logString.UTF8String);
#endif

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[ logString ] applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Private

- (CGSize)preferredContentSize {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat maxHeight = 500.f;
    CGFloat height = screenSize.height - 115.f;
    if (height > maxHeight)
        height = maxHeight;

    CGFloat maxWidth = 650.f;
    CGFloat width = screenSize.width - 75.f;
    if (width > maxWidth)
        width = maxWidth;
    return CGSizeMake(width, height);
}

#pragma mark - Actions

- (void)btnDoneDidClicked:(id)sender {
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger selectedRow = indexPath.row;
    if (self.currentSelectedRow == NSNotFound) {
        for (NSIndexPath *aIndexPath in [tableView indexPathsForSelectedRows]) {
            if ([aIndexPath compare:indexPath] == NSOrderedSame) {
                continue;
            }
            [tableView deselectRowAtIndexPath:aIndexPath animated:YES];
        }
        self.durationLabel.text = @"Select another time";
        self.currentSelectedRow = selectedRow;
    } else {
        NSUInteger minRow = MIN(self.currentSelectedRow, selectedRow);
        NSUInteger maxRow = MAX(self.currentSelectedRow, selectedRow);
        for (NSUInteger aRow = minRow; aRow <= maxRow; aRow++) {
            NSIndexPath *indexPathToSelect = [NSIndexPath indexPathForRow:aRow inSection:0];
            [tableView selectRowAtIndexPath:indexPathToSelect animated:YES scrollPosition:UITableViewScrollPositionNone];
        }

        NSTimeInterval maxTimeStamp = self.cellModels[maxRow].timeStamp;
        NSTimeInterval minTimeStamp = self.cellModels[minRow].timeStamp;
        NSTimeInterval selectedDuration = maxTimeStamp - minTimeStamp;
        if (maxTimeStamp < 0.1 || minTimeStamp < 0.1 || selectedDuration > 10000) {
            self.durationLabel.text = @"Invalid data";
        } else {
            self.durationLabel.text = [NSString stringWithFormat:@"Cost：%.3lfms", 1000 * selectedDuration];
        }

        self.currentSelectedRow = NSNotFound;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger selectedRow = indexPath.row;
    if (self.currentSelectedRow == NSNotFound) {
        for (NSIndexPath *aIndexPath in [tableView indexPathsForSelectedRows]) {
            [tableView deselectRowAtIndexPath:aIndexPath animated:YES];
        }
        [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        self.durationLabel.text = @"Select another time";
        self.currentSelectedRow = selectedRow;
    } else {
        self.durationLabel.text = @"Please select a time range";
        self.currentSelectedRow = NSNotFound;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHCallTraceTimeCostModel *timeCostModel = self.cellModels[indexPath.row].timeCostModel;
    MTHTimeIntervalCustomEventRecord *customRecord = self.cellModels[indexPath.row].customEvent;
    if (timeCostModel) {
        return [MTHUITimeProfilerResultCallTraceCell heightForCallTraceTimeCostModel:timeCostModel expanded:NO];
    } else if (customRecord) {
        return [MTHUITImeProfilerResultEventCell heightForEventRecord:customRecord expanded:NO];
    } else {
        return 36;
    }
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (self.cellModels[indexPath.row].timeCostModel) {
        MTHUITimeProfilerResultCallTraceCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(MTHUITimeProfilerResultCallTraceCell.class) forIndexPath:indexPath];
        [cell configureWithCallTraceTimeCostModel:self.cellModels[indexPath.row].timeCostModel expanded:NO];
        return cell;
    } else if (self.cellModels[indexPath.row].customEvent) {
        MTHUITImeProfilerResultEventCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(MTHUITImeProfilerResultEventCell.class) forIndexPath:indexPath];
        [cell configureWithEventRecord:self.cellModels[indexPath.row].customEvent expanded:NO];
        return cell;
    } else {
        MTHTimeIntervalStepsViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kReuseIdentifier];
        if (!cell) {
            cell = [[MTHTimeIntervalStepsViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kReuseIdentifier];
        }

        MTHTimeIntervalStepsViewCellModel *cellModel = self.cellModels[indexPath.row];
        cell.textLabel.text = cellModel.timeStampTitle;
        NSTimeInterval timeStamp = cellModel.timeStamp;
        if (timeStamp < 0.1) {
            cell.detailTextLabel.text = @"-";
        } else {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeStamp];
            cell.detailTextLabel.text = [self.dateFormatter stringFromDate:date];
        }
        return cell;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cellModels.count;
}

@end
