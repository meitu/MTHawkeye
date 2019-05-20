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

@property (nonatomic, copy) NSArray<MTHANRRecordRaw *> *records;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *recordTitles;

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
    if (self = [super init]) {
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
        if (fabs(insets.top - self.tableView.contentInset.top) < DBL_EPSILON) {
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
    self.records = [[[MTHANRHawkeyeAdaptor readANRRecords] reverseObjectEnumerator] allObjects];
    [self updateTableView];

    [self symbolicateRecordTitles];
}

- (void)symbolicateRecordTitles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        for (NSInteger ri = 0; ri < self.records.count; ++ri) {
            MTHANRRecordRaw *record = self.records[ri];
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
- (void)mth_anrMonitor:(MTHANRTrace *)anrMonitor didDetectANR:(MTHANRRecordRaw *)anrRecord {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateTableView];
    });
}

// MARK: - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.records.count > 0)
        return 2;
    else
        return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 1;
    else
        return self.records.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        MTHawkeyeSettingCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mt-hawkeye-setting" forIndexPath:indexPath];
        cell.model = [self remoteSymbolicisSwitcherCell];
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"anrCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"anrCell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.row < self.records.count) {
        MTHANRRecordRaw *anrRecord = self.records[indexPath.row];
        NSString *title = nil;
        NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:anrRecord.time]];
        if (anrRecord.duration > 0.f) {
            title = [NSString stringWithFormat:@"[%@]  ≈ %.2fs", time, anrRecord.duration / 1000.f];
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
    if (indexPath.section == 0)
        return NO;

    if (self.detailLoadingIndex < 0)
        return YES;
    else
        return self.detailLoadingIndex == indexPath.row;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0)
        return;

    if (self.detailLoadingIndex >= 0)
        return;

    if (indexPath.row < self.records.count) {
        self.detailLoadingIndex = indexPath.row;
        [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            MTHANRRecordRaw *anrRecord = self.records[indexPath.row];
            [self readANRRecordIntoReadableText:anrRecord
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

- (void)readANRRecordIntoReadableText:(MTHANRRecordRaw *)anrRecord completion:(void (^)(NSString *anrRecordDesc))completion {
    NSMutableString *content = [NSMutableString string];

    NSString *time = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:anrRecord.time]];
    [content appendString:@"\n"];
    [content appendFormat:@"Time: %@", time];
    [content appendString:@"\n"];

    CGFloat duration = anrRecord.duration / 1000.f;
    CGFloat threshold = [MTHANRTrace shared].thresholdInSeconds;
    CGFloat biases = threshold / 2.f; // according to [NSThread sleepForTimeInterval:xx / 4.f]
    NSString *blockingDesc = [NSString stringWithFormat:@"Blocking≈%.2fs(%.2f ~ %.2f+%.2f)", duration, duration, duration, biases];

    [content appendString:blockingDesc];
    [content appendString:@"\n\n"];

    if (anrReportSymbolicsRemote) {
        NSMutableArray *framesRaw = @[].mutableCopy;
        for (int i = 0; i < anrRecord->stackframesSize; ++i) {
            uintptr_t frame = anrRecord->stackframes[i];
            [framesRaw addObject:[NSString stringWithFormat:@"%p", (void *)frame]];
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
                       for (int i = 0; i < anrRecord->stackframesSize; ++i) {
                           uintptr_t frame = anrRecord->stackframes[i];
                           NSString *frameStr = [NSString stringWithFormat:@"%p", (void *)frame];
                           [content appendFormat:@"%*u %@\n", 2, i, outFrameDict[frameStr]];
                       }
                   }

                   completion(content.copy);
               }];

    } else {
        for (int i = 0; i < anrRecord->stackframesSize; ++i) {
            uintptr_t frame = anrRecord->stackframes[i];
            NSString *desc = [self recordFrameStringFrom:frame withoutFnameIfExistSname:NO];
            [content appendFormat:@"%*u %@\n", 2, i, desc];
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
