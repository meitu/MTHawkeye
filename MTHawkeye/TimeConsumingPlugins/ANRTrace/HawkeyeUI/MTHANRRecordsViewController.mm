//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import "MTHANRRecordsViewController.h"
#import "MTHANRHawkeyeAdaptor.h"
#import "MTHANRHawkeyeUI.h"
#import "MTHANRRecord.h"
#import "MTHANRTrace.h"
#import "MTHANRTracingBuffer.h"
#import "MTHawkeyeUserDefaults+ANRMonitor.h"

#import <MTHawkeye/MTHStackFrameSymbolics.h>
#import <MTHawkeye/MTHStackFrameSymbolicsRemote.h>
#import <MTHawkeye/MTHawkeyeDyldImagesStorage.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeSettingCell.h>
#import <MTHawkeye/MTHawkeyeSettingTableEntity.h>
#import <MTHawkeye/MTHawkeyeSettingViewController.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
#import <MTHawkeye/MTHawkeyeUtility.h>
#import <MTHawkeye/MTHawkeyeWebViewController.h>
#import <MTHawkeye/UITableView+MTHEmptyTips.h>
#import <MTHawkeye/UIViewController+MTHawkeyeCurrentViewController.h>
#import <MTHawkeye/UIViewController+MTHawkeyeLayoutSupport.h>


@interface MTHANRRecordsViewController () <MTHANRTraceDelegate, UITableViewDataSource, UITableViewDelegate> {
    MTHStackFrameSymbolics *stackHelper;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MTHANRTrace *anrMonitor;

@property (nonatomic, copy) NSArray<MTHANRRecord *> *records;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *recordTitles;

@property (nonatomic, strong) MTHANRTracingBuffer *previousSessionHardStallInfo;
@property (nonatomic, assign) BOOL previousSessionDetailLoading;

@property (nonatomic, assign) NSInteger detailLoadingIndex;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end


@implementation MTHANRRecordsViewController

- (void)dealloc {
    if (stackHelper) {
        delete stackHelper;
        stackHelper = nil;
    }

    [self.anrMonitor removeDelegate:self];
}

- (instancetype)initWithANRMonitor:(MTHANRTrace *)anrMonitor {
    if ((self = [super init])) {
        self.anrMonitor = anrMonitor;
        [self.anrMonitor addDelegate:self];
        self.recordTitles = @{}.mutableCopy;
        self.detailLoadingIndex = -1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ANR Records";

    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setDateFormat:@"HH:mm:ss:SSS"];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsZero;
    self.view = self.tableView;
    [self.tableView registerClass:[MTHawkeyeSettingCell class] forCellReuseIdentifier:@"mt-hawkeye-setting"];

    [self loadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateTableView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
    } else {
        UIEdgeInsets insets = UIEdgeInsetsMake([self mt_hawkeye_navigationBarTopLayoutGuide].length, 0, 0, 0);
        if (fabs(insets.top - self.tableView.contentInset.top) > DBL_EPSILON) {
            self.tableView.contentInset = insets;
            self.tableView.scrollIndicatorInsets = insets;
            self.tableView.contentOffset = CGPointMake(0, -insets.top);
        }
    }
#endif
}

- (void)updateTableView {
    if (self.records.count == 0) {
        if (![MTHawkeyeUserDefaults shared].anrTraceOn) {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Application Not Responding tracing is OFF"
                                                         tipsTop:80.f
                                                          button:@"Go to Setting"
                                                       btnTarget:self
                                                       btnAction:@selector(gotoSetting)];
        } else {
            NSString *tips = [NSString stringWithFormat:@"Empty Records\n\nCurrent ANR Threshold: %.2fs", self.anrMonitor.thresholdInSeconds];
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:tips];
        }
    } else {
        [self.tableView mthawkeye_removeEmptyTipsFooterView];
    }

    [self.tableView reloadData];
}

- (void)loadData {
    NSString *prevSessionBufferPath = [[MTHawkeyeUtility previousSessionStorePath] stringByAppendingPathComponent:@"anr_tracing_buffer"];
    [MTHANRTracingBufferRunner
        readPreviousSessionBufferAtPath:prevSessionBufferPath
                      completionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
                          if (buffer) {
                              if (!buffer.isAppStillActiveTheLastMoment) return;

                              // show hardstall info even only exit unexpected captured.
                              self.previousSessionHardStallInfo = buffer;
                              MTHLogInfo(@"Previous session exit unexpected.");

                              if (buffer.isDuringHardStall) {
                                  MTHLogWarn(@"Captured hard stall on previous session.");
                              }
                          }
                      }];

    self.records = [[[MTHANRHawkeyeAdaptor readANRRecords] reverseObjectEnumerator] allObjects];
    [self updateTableView];

    [self symbolicateRecordTitles];
}

- (void)symbolicateRecordTitles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        for (NSInteger ri = 0; ri < self.records.count; ++ri) {
            uintptr_t highlightTitleFrame = 0;
            if (self.records[ri].stallingSnapshots.count > 0 && self.records[ri].stallingSnapshots.count <= 2) {
                highlightTitleFrame = ((MTHANRMainThreadStallingSnapshot *)[self.records[ri].stallingSnapshots lastObject])->titleFrame;
            } else if (self.records[ri].stallingSnapshots.count > 0) {
                NSCountedSet *titleFrameCounter = [NSCountedSet set];
                for (MTHANRMainThreadStallingSnapshot *snapshot in self.records[ri].stallingSnapshots) {
                    [titleFrameCounter addObject:@(snapshot->titleFrame)];
                }

                NSArray *sortedTitleFrame = [titleFrameCounter.allObjects sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
                    NSUInteger n = [titleFrameCounter countForObject:obj1];
                    NSUInteger m = [titleFrameCounter countForObject:obj2];
                    return (n < m) ? NSOrderedAscending : NSOrderedDescending;
                }];

                highlightTitleFrame = [[sortedTitleFrame.reverseObjectEnumerator.allObjects firstObject] integerValue];
            }

            NSString *riStr = [NSString stringWithFormat:@"%ld", (long)ri];

            @synchronized(self.recordTitles) {
                self.recordTitles[riStr] = [self recordFrameStringFrom:highlightTitleFrame withoutFnameIfExistSname:YES];
            }
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if ([self.tableView numberOfRowsInSection:1] < ri) {
                    NSIndexPath *reloadPath = [NSIndexPath indexPathForRow:ri inSection:1];
                    [self.tableView reloadRowsAtIndexPaths:@[ reloadPath ] withRowAnimation:UITableViewRowAnimationNone];
                }
            });
        }
    });
}

- (NSString *)recordFrameStringFrom:(uintptr_t)frame withoutFnameIfExistSname:(BOOL)shortV {
    NSString *title = nil;
    Dl_info dlinfo = {NULL, NULL, NULL, NULL};

    if (!self->stackHelper) {
        self->stackHelper = new MTHStackFrameSymbolics();
    }
    self->stackHelper->getDLInfoByAddr(frame, &dlinfo, true);

    if (dlinfo.dli_sname) {
        if (shortV)
            title = [NSString stringWithFormat:@"%s", dlinfo.dli_sname];
        else
            title = [NSString stringWithFormat:@"%s %s", dlinfo.dli_fname, dlinfo.dli_sname];
    } else {
        title = [NSString stringWithFormat:@"%s %p %p", dlinfo.dli_fname, dlinfo.dli_fbase, dlinfo.dli_saddr];
    }
    return title;
}

// MARK: - MTHANRTraceDelegate
- (void)mth_anrMonitor:(MTHANRTrace *)anrMonitor didDetectANR:(MTHANRRecord *)anrRecord {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateTableView];
    });
}

// MARK: - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.records.count == 0 && self.previousSessionHardStallInfo)
        return 1;
    else if (self.records.count > 0)
        return self.previousSessionHardStallInfo ? 3 : 2;
    else
        return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return self.records.count;
    } else {
        return 1; // previous session buffer context
    }
}

- (BOOL)isRemoteSymbolicSwitchCell:(NSIndexPath *)indexPath {
    return indexPath.section == 0 && self.records.count > 0;
}

- (BOOL)isPreviousSessionHardStallCell:(NSIndexPath *)indexPath {
    // the last section or the only section.
    return (indexPath.section == 2) || (indexPath.section == 0 && self.records.count == 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isRemoteSymbolicSwitchCell:indexPath]) {
        MTHawkeyeSettingCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mt-hawkeye-setting" forIndexPath:indexPath];
        cell.model = [self remoteSymbolicisSwitcherCell];
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"anrCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"anrCell"];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if ([self isPreviousSessionHardStallCell:indexPath]) { // previous session buffer context
        [self _updateCell:cell withHardStallInfo:self.previousSessionHardStallInfo];
    } else if (indexPath.row < self.records.count) {
        [self _updateANRRecordCell:cell atIndexPath:indexPath];
    } else {
        cell.textLabel.text = @"";
    }

    return cell;
}

- (void)_updateCell:(UITableViewCell *)cell withHardStallInfo:(MTHANRTracingBuffer *)hardStallInfo {
    cell.textLabel.text = @"Previous session exit unexpected";
    if (self.previousSessionHardStallInfo.isDuringHardStall) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"And hard stalling at least %.0f seconds", self.previousSessionHardStallInfo.hardStallDurationInSeconds];
        if (self.previousSessionDetailLoading) {
            UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            cell.accessoryView = loadingView;
            [loadingView startAnimating];
        } else {
            cell.accessoryView = nil;
        }
    } else {
        cell.detailTextLabel.text = @"None hard stalling event captured.";
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)_updateANRRecordCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    MTHANRRecord *stallingRecord = self.records[indexPath.row];
    NSTimeInterval stallingStartFrom = stallingRecord.startFrom;
    NSString *title = nil;
    NSString *startAtStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:stallingStartFrom]];
    if (stallingRecord.durationInSeconds > 0.f) {
        title = [NSString stringWithFormat:@"[%@] stalling %.2fs", startAtStr, stallingRecord.durationInSeconds / 1000.f];
    } else {
        title = [NSString stringWithFormat:@"[%@] stalling > %.2fs", startAtStr, [MTHANRTrace shared].thresholdInSeconds];
    }
    cell.textLabel.text = title;
    @synchronized(self.recordTitles) {
        NSString *detail = self.recordTitles[[NSString stringWithFormat:@"%ld", (long)indexPath.row]];
        if (detail.length > 0) {
            cell.detailTextLabel.text = detail;
        } else {
            cell.detailTextLabel.text = @"loading";
        }
    }

    if (self.detailLoadingIndex == indexPath.row) {
        UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        cell.accessoryView = loadingView;
        [loadingView startAnimating];
    } else {
        cell.accessoryView = nil;
    }
}

static BOOL anrReportSymbolicsRemote = NO;
- (MTHawkeyeSettingSwitcherCellEntity *)remoteSymbolicisSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Remote Symbolics";
    entity.setupValueHandler = ^BOOL {
        id value = [[MTHawkeyeUserDefaults shared] objectForKey:@"anr-report-remote-symbolics"];
        anrReportSymbolicsRemote = value ? [value boolValue] : NO;
        return anrReportSymbolicsRemote;
    };

#ifdef DEBUG
    entity.frozen = YES;
#endif

    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != anrReportSymbolicsRemote) {
            anrReportSymbolicsRemote = newValue;
            [[MTHawkeyeUserDefaults shared] setObject:@(newValue) forKey:@"anr-report-remote-symbolics"];
        }

        if (newValue && [MTHStackFrameSymbolicsRemote symbolicsServerURL].length == 0) {
            NSString *msg = @"To symbolize the stack frames.\n\n Setup `symbolicsServerURL` in `MTHStackFrameRemoteSymbolics.h` or `mthAllocationSymbolicsHandler`, and turn on `Remote Symbolics`. \n\nThen generate the report again.";
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Symbolics Server Needed"
                                                                                     message:msg
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [alertController addAction:action];

            [[UIViewController mth_topViewController] presentViewController:alertController animated:YES completion:nil];
        }
        return YES;
    };
    return entity;
}

// MARK: UITableViewDelegate
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isRemoteSymbolicSwitchCell:indexPath])
        return NO;

    if ([self isPreviousSessionHardStallCell:indexPath])
        return !self.previousSessionDetailLoading;

    if (self.detailLoadingIndex < 0)
        return YES;
    else
        return self.detailLoadingIndex == indexPath.row;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isRemoteSymbolicSwitchCell:indexPath])
        return;

    // previous hard stalling cell.
    if ([self isPreviousSessionHardStallCell:indexPath]) {
        if (self.previousSessionDetailLoading)
            return;

        self.previousSessionDetailLoading = YES;
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self convertPreviousHardStallInfo:self.previousSessionHardStallInfo
                intoReadableDescriptionWithCompletionHandler:^(NSString *desc) {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        self.previousSessionDetailLoading = NO;
                        [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];

                        MTHawkeyeWebViewController *vc = [[MTHawkeyeWebViewController alloc] initWithText:desc];
                        [self.navigationController pushViewController:vc animated:YES];
                    });
                }];
        });
        return;
    }

    // anr records
    if (self.detailLoadingIndex >= 0)
        return;

    if (indexPath.row < self.records.count) {
        self.detailLoadingIndex = indexPath.row;
        [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self readANRRecordIntoReadableText:self.records[indexPath.row]
                                     completion:^(NSString *anrRecordDesc) {
                                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                                             self.detailLoadingIndex = -1;
                                             [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
                                             [tableView deselectRowAtIndexPath:indexPath animated:YES];

                                             MTHawkeyeWebViewController *vc = [[MTHawkeyeWebViewController alloc] initWithText:anrRecordDesc];
                                             [self.navigationController pushViewController:vc animated:YES];
                                         });
                                     }];
        });
    }
}

// MARK: hard stall detail description generator
- (void)convertPreviousHardStallInfo:(MTHANRTracingBuffer *)hardStallInfo
    intoReadableDescriptionWithCompletionHandler:(void (^)(NSString *desc))completion {

    if (!completion) return;

    if (!(hardStallInfo.runloopActivities.count > 0 && hardStallInfo.applifeActivities.count > 0 && hardStallInfo.backtraceRecords.count > 0)) {
        completion([NSString stringWithFormat:@"ANRTracingBuffer incomplete:\n \
                   runloop activities:\n%@ \n\n \
                   applife activities:\n%@ \n\n \
                   backtrace records:\n%@ \n\n", hardStallInfo.runloopActivities, hardStallInfo.applifeActivities, hardStallInfo.backtraceRecords]);
        return;
    }
    if (!(hardStallInfo.runloopActivities.count == hardStallInfo.runloopActivitiesTimes.count
            && hardStallInfo.applifeActivities.count == hardStallInfo.applifeActivitiesTimes.count
            && hardStallInfo.backtraceRecords.count == hardStallInfo.backtraceRecordTimes.count)) {
        completion(@"ANRTracingBuffer data broken, the records should be in pair.");
        return;
    }

    void (^symbolicsCompletion)(NSDictionary<NSString *, NSString *> *_Nullable symbolizedFrames, NSString *_Nullable symbolicsErrorInfo) = ^(NSDictionary<NSString *, NSString *> *_Nullable symbolizedFrames, NSString *_Nullable symbolicsErrorInfo) {
        NSMutableString *content = [NSMutableString string];

        NSString *title = [NSString stringWithFormat:@"Previous session exit unexpected, \nAnd hard stalling at least %.0fs \n (From last runloop activity to last backtrace record.)\n\n", hardStallInfo.hardStallDurationInSeconds];

        [content appendString:title];

        if (symbolicsErrorInfo.length > 0) {
            [content appendFormat:@"%@\n\n", symbolicsErrorInfo];
        }

        NSTimeInterval lastRunloopActivityTime = [hardStallInfo lastRunloopAcvitityTime];
        NSString *lastRunloopActivityDesc = nil;
        // last runloop activity desc:
        {
            NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:lastRunloopActivityTime]];
            NSString *activityStr = mthStringFromRunloopActivity([hardStallInfo lastRunloopActivity]);

            lastRunloopActivityDesc = [NSString stringWithFormat:@"%@: %@ (last runloop acvitity)", timeStr, activityStr];
            [content appendFormat:@"\n%@ \n\n", lastRunloopActivityDesc];
        }

        // backtrace after last runloop activity desc:
        {
            [content appendString:@"\n\n---- stack backtrace *after* last runloop activity ----\n\n"];
            for (NSInteger i = 0; i < hardStallInfo.backtraceRecordTimes.count; ++i) {
                NSNumber *timeNum = hardStallInfo.backtraceRecordTimes[i];
                NSTimeInterval btTime = [timeNum doubleValue];
                if (btTime < lastRunloopActivityTime)
                    continue;

                NSArray<NSNumber *> *backtrace = hardStallInfo.backtraceRecords[i];
                [self _appendBacktrace:backtrace time:btTime frameSymbolDict:symbolizedFrames toContent:content];
            }
            [content appendString:@"\n----\n"];
        }

        // the lastest runloop activities
        {
            [content appendString:@"\n\n---- the lastest runloop activities ----\n\n"];
            NSInteger startIndex = hardStallInfo.runloopActivities.count;
            if (startIndex > 5) {
                startIndex = startIndex - 5; // only displaty the last 5 activities
            }

            for (NSInteger i = startIndex; i < hardStallInfo.runloopActivities.count; ++i) {
                NSTimeInterval time = [hardStallInfo.runloopActivitiesTimes[i] doubleValue];
                CFRunLoopActivity activity = (CFRunLoopActivity)[hardStallInfo.runloopActivities[i] integerValue];
                NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
                [content appendFormat:@"%@: %@\n", timeStr, mthStringFromRunloopActivity(activity)];
            }
            [content appendString:@"\n----\n"];
        }

        // the lastest applife activities
        {
            [content appendString:@"\n\n---- the lastest applife activities ----\n\n"];
            for (NSInteger i = 0; i < hardStallInfo.applifeActivities.count; ++i) {
                NSTimeInterval time = [hardStallInfo.applifeActivitiesTimes[i] doubleValue];
                MTHawkeyeAppLifeActivity activity = (MTHawkeyeAppLifeActivity)[hardStallInfo.applifeActivities[i] integerValue];

                NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
                [content appendFormat:@"%@: %@\n", timeStr, mthStringFromAppLifeActivity(activity)];
            }
            [content appendString:@"\n----\n"];
        }

        // backtrace before last runloop activity desc:
        {
            [content appendFormat:@"\n\n---- stack backtrace *before* last runloop activity ----\n%@\n\n", lastRunloopActivityDesc];
            for (NSInteger i = 0; i < hardStallInfo.backtraceRecordTimes.count; ++i) {
                NSNumber *timeNum = hardStallInfo.backtraceRecordTimes[i];
                NSTimeInterval btTime = [timeNum doubleValue];
                if (btTime >= lastRunloopActivityTime)
                    continue;

                NSArray<NSNumber *> *backtrace = hardStallInfo.backtraceRecords[i];
                [self _appendBacktrace:backtrace time:btTime frameSymbolDict:symbolizedFrames toContent:content];
            }
            [content appendString:@"\n----\n\n"];
        }

        completion(content);
    };

    NSMutableArray *framesRaw = @[].mutableCopy;
    for (NSArray<NSNumber *> *backtrace in hardStallInfo.backtraceRecords) {
        for (NSNumber *frame in backtrace) {
            [framesRaw addObject:[NSString stringWithFormat:@"%p", (void *)[frame integerValue]]];
        }
    }
    framesRaw = [[[NSSet setWithArray:framesRaw] allObjects] copy];

    if ([MTHStackFrameSymbolicsRemote symbolicsServerURL].length > 0) {
        [MTHStackFrameSymbolicsRemote
            symbolizeStackFrames:framesRaw
             withDyldImagesInfos:[MTHawkeyeDyldImagesStorage previousSessionCachedDyldImagesInfo]
               completionHandler:^(NSArray<NSDictionary<NSString *, NSString *> *> *_Nonnull symbolizedFrames, NSError *_Nonnull error) {
                   if (error) {
                       symbolicsCompletion(nil, [NSString stringWithFormat:@"%@", error]);
                   } else {
                       NSMutableDictionary<NSString *, NSString *> *outFrameDict = @{}.mutableCopy;
                       [self formatRemoteSymolizedFramesDicts:symbolizedFrames intoOnlineFrame:outFrameDict];
                       symbolicsCompletion(outFrameDict, nil);
                   }
               }];
    } else {
        symbolicsCompletion(nil, @"****\nRemote Symbolics Server Needed. \n(See MTHStackFrameSymbolicsRemote.h)\n***");
    }
}

- (void)_appendBacktrace:(NSArray<NSNumber *> *)backtrace
                    time:(NSTimeInterval)time
         frameSymbolDict:(NSDictionary<NSString *, NSString *> *)frameSymbolDict
               toContent:(NSMutableString *)content {
    NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
    [content appendFormat:@"%@:\n", timeStr];
    for (int i = 0; i < backtrace.count; ++i) {
        NSInteger frame = [backtrace[i] integerValue];
        NSString *frameInStr = [NSString stringWithFormat:@"%p", (void *)frame];
        if (frameSymbolDict[frameInStr]) {
            [content appendFormat:@"%*u %@\n", 2, i, frameSymbolDict[frameInStr]];
        } else {
            [content appendFormat:@"%*u %@\n", 2, i, frameInStr];
        }
    }
    [content appendString:@"\n"];
}

// MARK:
- (void)readANRRecordIntoReadableText:(MTHANRRecord *)anrRecord completion:(void (^)(NSString *anrRecordDesc))completion {
    NSMutableString *content = [NSMutableString string];

    CGFloat duration = anrRecord.durationInSeconds / 1000.f;
    NSString *stallingDesc = [NSString stringWithFormat:@"Stalling %.2f seconds\n", duration];
    [content appendString:stallingDesc];

    if (anrReportSymbolicsRemote) {
        NSMutableArray *framesRaw = @[].mutableCopy;
        for (MTHANRMainThreadStallingSnapshot *rawRecord in anrRecord.stallingSnapshots) {
            for (int i = 0; i < rawRecord->stackframesSize; ++i) {
                uintptr_t frame = rawRecord->stackframes[i];
                [framesRaw addObject:[NSString stringWithFormat:@"%p", (void *)frame]];
            }
        }

        [MTHStackFrameSymbolicsRemote
            symbolizeStackFrames:[framesRaw copy]
             withDyldImagesInfos:[MTHawkeyeDyldImagesStorage cachedDyldImagesInfo]
               completionHandler:^(NSArray<NSDictionary<NSString *, NSString *> *> *_Nonnull symbolizedFrames, NSError *_Nonnull error) {
                   if (error) {
                       [content appendFormat:@"%@", error];
                   } else {
                       NSMutableDictionary<NSString *, NSString *> *outFrameDict = @{}.mutableCopy;
                       [self formatRemoteSymolizedFramesDicts:symbolizedFrames intoOnlineFrame:outFrameDict];
                       for (MTHANRMainThreadStallingSnapshot *rawRecord in anrRecord.stallingSnapshots) {
                           NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:rawRecord.time]];
                           [content appendFormat:@"\n Timestamp:%@ \n", time];
                           for (int i = 0; i < rawRecord->stackframesSize; ++i) {
                               uintptr_t frame = rawRecord->stackframes[i];
                               NSString *frameStr = [NSString stringWithFormat:@"%p", (void *)frame];
                               [content appendFormat:@"%*u %@\n", 2, i, outFrameDict[frameStr] ?: frameStr];
                           }
                       }
                   }

                   completion(content.copy);
               }];

    } else {
        for (MTHANRMainThreadStallingSnapshot *rawRecord in anrRecord.stallingSnapshots) {
            NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:rawRecord.time]];
            [content appendFormat:@"\n Timestamp: %@ \n", time];
            for (int i = 0; i < rawRecord->stackframesSize; ++i) {
                uintptr_t frame = rawRecord->stackframes[i];
                NSString *desc = [self recordFrameStringFrom:frame withoutFnameIfExistSname:NO];
                [content appendFormat:@"%*u %@\n", 2, i, desc];
            }
        }
        completion(content.copy);
    }
}

- (void)formatRemoteSymolizedFramesDicts:(NSArray<NSDictionary<NSString *, NSString *> *> *)remoteSymblizedFrames
                         intoOnlineFrame:(NSMutableDictionary<NSString *, NSString *> *)outFrameDict {
    for (NSDictionary<NSString *, NSString *> *frameInfo in remoteSymblizedFrames) {
        if (![frameInfo isKindOfClass:[NSDictionary class]]) {
            MTHLogWarn(@" unexpected frameInfo: %@", frameInfo);
            continue;
        }

        NSString *frameKey = frameInfo[@"addr"];
        if (frameKey.length == 0)
            continue;

        NSString *fname = frameInfo[@"fname"];
        NSString *fbase = frameInfo[@"fbase"];
        NSString *sname = frameInfo[@"sname"];
        NSString *sbase = frameInfo[@"sbase"];
        NSMutableString *frameDealed = [NSMutableString string];
        if (fname.length > 0) {
            [frameDealed appendFormat:@"%@  ", fname];
        } else if (fbase.length > 0) {
            [frameDealed appendFormat:@"%@  ", fbase];
        }
        if (sname.length > 0) {
            [frameDealed appendFormat:@"%@", sname];
        } else if (sbase.length > 0) {
            [frameDealed appendFormat:@"%@", sbase];
        } else {
            [frameDealed appendFormat:@"%@", frameKey];
        }

        outFrameDict[frameKey] = [frameDealed copy];
    }
}

// MARK: - Utils

- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = ((MTHawkeyeSettingFoldedCellEntity *)[MTHANRHawkeyeUI settings]).foldedSections;
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"ANR" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
