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

@property (nonatomic, assign) BOOL showPreviousSessionRearmostContext;

@property (nonatomic, assign) NSTimeInterval previousSessionHardStallTimeRough;
@property (nonatomic, copy) NSString *previousSessionHardStallDescTitle;
@property (nonatomic, copy) NSString *previousSessionHardStallDescSubTitle;
@property (nonatomic, copy) NSDictionary *previousSessionHardStallDetail;
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
    [MTHANRTracingBuffer readPreviousSessionBufferInDict:^(NSDictionary *_Nullable dict) {
        [self checkIfPreviousSessionCrashUnexpected:dict];
        MTHLog(@"previous anr buffer context: %@", dict);
    }];

    self.records = [[[MTHANRHawkeyeAdaptor readANRRecords] reverseObjectEnumerator] allObjects];
    [self updateTableView];

    [self symbolicateRecordTitles];
}

- (void)checkIfPreviousSessionCrashUnexpected:(NSDictionary *)preSessionANRContext {
    self.showPreviousSessionRearmostContext = NO;

    NSArray *applifeActivities = preSessionANRContext[@"applife"];
    if (applifeActivities.count == 0) {
        MTHLogWarn(@"the previous session applife activities records is empty.");
        return;
    }

    BOOL isPreSessionActive = YES;
    NSTimeInterval lastMemoryWarningTime = 0;
    for (NSDictionary *activityDict in [applifeActivities.reverseObjectEnumerator allObjects]) {
        NSInteger activity = [activityDict[@"activity"] integerValue];
        if (isPreSessionActive && (activity == MTHawkeyeAppLifeActivityWillTerminate || activity == MTHawkeyeAppLifeActivityDidEnterBackground)) {
            isPreSessionActive = NO;
        }
        if (lastMemoryWarningTime == 0 && activity == MTHawkeyeAppLifeActivityMemoryWarning) {
            lastMemoryWarningTime = [activityDict[@"time"] doubleValue];
        }
    }

    if (!isPreSessionActive) {
        // previous session normally exit.
        return;
    }

    NSTimeInterval fromLastRunloopActivityToLastBacktrace = 0;
    NSArray *runloopActivities = preSessionANRContext[@"runloop"];
    NSArray *backtraceList = preSessionANRContext[@"stackbacktrace"];

    NSDictionary *lastRLActivity = nil;
    NSTimeInterval lastRLActivityTime = 0;

    if (runloopActivities.count == 0 || backtraceList.count == 0) {
        if (runloopActivities.count == 0) MTHLogInfo(@"the previous session runloop activities records is empty.");
        if (backtraceList.count == 0) MTHLogInfo(@"the previous session backtrace records is empty.");
    } else {
        lastRLActivity = [runloopActivities lastObject];
        lastRLActivityTime = [lastRLActivity[@"time"] doubleValue];

        NSDictionary *lastBacktrace = [backtraceList lastObject];
        NSTimeInterval lastBTTime = [lastBacktrace[@"time"] doubleValue];

        fromLastRunloopActivityToLastBacktrace = lastBTTime - lastRLActivityTime;
    }

    if (fromLastRunloopActivityToLastBacktrace <= 0) {
        self.previousSessionHardStallDescTitle = @"Previous session exit unexpected";
        self.previousSessionHardStallDescSubTitle = @"Empty stall record captured.";
        return;
    }

    self.showPreviousSessionRearmostContext = YES;

    // when the app killed, it still amoung the stall, we could only get the rough time.
    self.previousSessionHardStallTimeRough = fromLastRunloopActivityToLastBacktrace;
    self.previousSessionHardStallDescTitle = @"Previous session exit unexpected";
    self.previousSessionHardStallDescSubTitle = [NSString stringWithFormat:@"Stall at least %.0fs", self.previousSessionHardStallTimeRough];

    NSMutableArray *btBeforeLast = @[].mutableCopy;
    NSMutableArray *btAfterLast = @[].mutableCopy;

    for (NSDictionary *bt in backtraceList) {
        NSTimeInterval time = [bt[@"time"] doubleValue];
        if (time > lastRLActivityTime) {
            [btAfterLast addObject:bt];
        } else {
            [btBeforeLast addObject:bt];
        }
    }

    self.previousSessionHardStallDetail = @{
        @"btAfter" : [btAfterLast copy],
        @"btBefore" : [btBeforeLast copy],
        @"lastRunloopActivity" : lastRLActivity,
        @"runloopActivities" : runloopActivities,
        @"appLifeActivities" : applifeActivities,
    };
}

- (void)symbolicateRecordTitles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        for (NSInteger ri = 0; ri < self.records.count; ++ri) {
            MTHANRRecordRaw *record = [self.records[ri].rawRecords firstObject];
            NSString *riStr = [NSString stringWithFormat:@"%ld", (long)ri];

            @synchronized(self.recordTitles) {
                self.recordTitles[riStr] = [self recordFrameStringFrom:record->titleFrame withoutFnameIfExistSname:YES];
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
    if (self.records.count == 0 && self.showPreviousSessionRearmostContext)
        return 1;
    else if (self.records.count > 0)
        return self.showPreviousSessionRearmostContext ? 3 : 2;
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
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if ([self isPreviousSessionHardStallCell:indexPath]) { // previous session buffer context
        cell.textLabel.text = self.previousSessionHardStallDescTitle;
        cell.detailTextLabel.text = self.previousSessionHardStallDescSubTitle;
        if (self.previousSessionHardStallDetail) {
            if (self.previousSessionDetailLoading) {
                UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                cell.accessoryView = loadingView;
                [loadingView startAnimating];
            } else {
                cell.accessoryView = nil;
            }
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.row < self.records.count) {
        MTHANRRecordRaw *anrRecord = [self.records[indexPath.row].rawRecords firstObject];
        NSString *title = nil;
        NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:anrRecord.time]];
        if (self.records[indexPath.row].duration > 0.f) {
            title = [NSString stringWithFormat:@"[%@]  ≈ %.2fs", time, self.records[indexPath.row].duration / 1000.f];
        } else {
            title = [NSString stringWithFormat:@"[%@]  > %.2fs", time, [MTHANRTrace shared].thresholdInSeconds];
        }
        cell.textLabel.text = title;
        @synchronized(self.recordTitles) {
            NSString *title = self.recordTitles[[NSString stringWithFormat:@"%ld", (long)indexPath.row]];
            if (title.length > 0) {
                cell.detailTextLabel.text = title;
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
    } else {
        cell.textLabel.text = @"";
    }

    return cell;
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

    // previous hard stall cell.
    if ([self isPreviousSessionHardStallCell:indexPath]) {
        if (self.previousSessionDetailLoading)
            return;

        self.previousSessionDetailLoading = YES;
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self convertPreviousHardStallInfo:self.previousSessionHardStallDetail
                readableResultCompletionHandler:^(NSString *desc) {
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

- (void)convertPreviousHardStallInfo:(NSDictionary *)previousSessionHardStall readableResultCompletionHandler:(void (^)(NSString *desc))completion {
    NSArray *btAfterLastActivity = self.previousSessionHardStallDetail[@"btAfter"];
    NSArray *btBeforeLastActivity = self.previousSessionHardStallDetail[@"btBefore"];


    void (^symbolicsCompletion)(NSDictionary<NSString *, NSString *> *_Nullable symbolizedFrames, NSString *_Nullable symbolicsErrorInfo) = ^(NSDictionary<NSString *, NSString *> *_Nullable symbolizedFrames, NSString *_Nullable symbolicsErrorInfo) {
        NSMutableString *content = [NSMutableString string];

        NSString *title = [NSString stringWithFormat:@"Previous session exit unexpected, stall at least %.0fs \n (From last runloop activity to last backtrace record.)\n\n", self.previousSessionHardStallTimeRough];

        [content appendString:title];

        if (symbolicsErrorInfo.length > 0) {
            [content appendFormat:@"%@\n\n", symbolicsErrorInfo];
        }

        NSDictionary *lastRunloopActivity = self.previousSessionHardStallDetail[@"lastRunloopActivity"];
        NSString *lastRunloopActivityDesc = nil;
        if (lastRunloopActivity.count > 0) {
            NSTimeInterval time = [lastRunloopActivity[@"time"] doubleValue];
            NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
            lastRunloopActivityDesc = [NSString stringWithFormat:@"%@: %@ (last runloop activity)", timeStr, lastRunloopActivity[@"activity"]];
            [content appendFormat:@"\n%@\n\n", lastRunloopActivityDesc];
        }

        [content appendString:@"\n\n---- stack backtrace *after* last runloop activity ----\n\n"];
        if (btAfterLastActivity.count > 0) {
            for (NSDictionary *btDict in btAfterLastActivity) {
                NSTimeInterval time = [btDict[@"time"] doubleValue];
                NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
                [content appendFormat:@"%@:\n", timeStr];
                NSArray *rawFrames = [btDict[@"frames"] componentsSeparatedByString:@","];
                for (int i = 0; i < rawFrames.count; ++i) {
                    NSString *rawFrame = rawFrames[i];
                    if (symbolizedFrames[rawFrame]) {
                        [content appendFormat:@"%*u %@\n", 2, i, symbolizedFrames[rawFrame]];
                    } else {
                        [content appendFormat:@"%*u %@\n", 2, i, rawFrame];
                    }
                }
                [content appendString:@"\n"];
            }
        }
        [content appendString:@"\n----\n"];

        [content appendString:@"\n\n---- the lastest runloop activities ----\n\n"];

        NSArray *runloopActivities = self.previousSessionHardStallDetail[@"runloopActivities"];
        // only display the last 5
        if (runloopActivities.count > 5)
            runloopActivities = [runloopActivities subarrayWithRange:NSMakeRange(runloopActivities.count - 5, 5)];

        for (NSDictionary *activityDict in runloopActivities) {
            NSTimeInterval time = [activityDict[@"time"] doubleValue];
            NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
            [content appendFormat:@"%@: %@\n", timeStr, activityDict[@"activity"]];
        }
        [content appendString:@"\n----\n"];

        [content appendString:@"\n\n---- the lastest applife activities ----\n\n"];
        NSArray *appLifeActivities = self.previousSessionHardStallDetail[@"appLifeActivities"];
        for (NSDictionary *activityDict in appLifeActivities) {
            NSTimeInterval time = [activityDict[@"time"] doubleValue];
            NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
            [content appendFormat:@"%@: %@\n", timeStr, activityDict[@"activity"]];
        }
        [content appendString:@"\n----\n"];

        [content appendFormat:@"\n\n---- stack backtrace *before* last runloop activity ----\n%@\n\n", lastRunloopActivityDesc];
        if (btBeforeLastActivity.count > 0) {
            for (NSDictionary *btDict in btBeforeLastActivity) {
                NSTimeInterval time = [btDict[@"time"] doubleValue];
                NSString *timeStr = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
                [content appendFormat:@"%@:\n", timeStr];
                NSArray *rawFrames = [btDict[@"frames"] componentsSeparatedByString:@","];
                for (int i = 0; i < rawFrames.count; ++i) {
                    NSString *rawFrame = rawFrames[i];
                    if (symbolizedFrames[rawFrame]) {
                        [content appendFormat:@"%*u %@\n", 2, i, symbolizedFrames[rawFrame]];
                    } else {
                        [content appendFormat:@"%*u %@\n", 2, i, rawFrame];
                    }
                }
                [content appendString:@"\n"];
            }
        }
        [content appendString:@"\n----\n\n"];

        completion(content);
    };

    NSMutableArray *framesRaw = @[].mutableCopy;
    for (NSDictionary *btDict in btAfterLastActivity) {
        [framesRaw addObjectsFromArray:[btDict[@"frames"] componentsSeparatedByString:@","]];
    }
    for (NSDictionary *btDict in btBeforeLastActivity) {
        [framesRaw addObjectsFromArray:[btDict[@"frames"] componentsSeparatedByString:@","]];
    }

    if ([MTHStackFrameSymbolicsRemote symbolicsServerURL].length > 0) {
        [MTHStackFrameSymbolicsRemote
            symbolizeStackFrames:[framesRaw copy]
             withDyldImagesInfos:[MTHawkeyeDyldImagesStorage cachedDyldImagesInfo]
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

// MARK:
- (void)readANRRecordIntoReadableText:(MTHANRRecord *)anrRecord completion:(void (^)(NSString *anrRecordDesc))completion {
    NSMutableString *content = [NSMutableString string];

    CGFloat duration = anrRecord.duration / 1000.f;
    CGFloat biases = anrRecord.biases / 1000.f;
    NSString *blockingDesc = [NSString stringWithFormat:@"Blocking≈%.2fs(%.2f-%.2f ~ %.2f) \n", duration, duration, biases, duration];
    [content appendString:blockingDesc];

    if (anrReportSymbolicsRemote) {
        NSMutableArray *framesRaw = @[].mutableCopy;
        for (MTHANRRecordRaw *rawRecord in anrRecord.rawRecords) {
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
                       for (MTHANRRecordRaw *rawRecord in anrRecord.rawRecords) {
                           NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:rawRecord.time]];
                           [content appendFormat:@"\n Timestamp:%@ \n", time];
                           for (int i = 0; i < rawRecord->stackframesSize; ++i) {
                               uintptr_t frame = rawRecord->stackframes[i];
                               NSString *frameStr = [NSString stringWithFormat:@"%p", (void *)frame];
                               [content appendFormat:@"%*u %@\n", 2, i, outFrameDict[frameStr]];
                           }
                       }
                   }

                   completion(content.copy);
               }];

    } else {
        for (MTHANRRecordRaw *rawRecord in anrRecord.rawRecords) {
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
