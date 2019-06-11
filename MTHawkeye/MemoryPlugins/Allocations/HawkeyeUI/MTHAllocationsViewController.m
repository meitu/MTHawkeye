//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/20
// Created by: EuanC
//


#import "MTHAllocationsViewController.h"
#import "MTHAHistoryRecordReader.h"
#import "MTHAllocations.h"
#import "MTHAllocationsHawkeyeUI.h"
#import "MTHAllocationsSettingEntity.h"
#import "MTHawkeyeUserDefaults+Allocations.h"

#import <MTHawkeye/MTHStackFrameSymbolicsRemote.h>
#import <MTHawkeye/MTHawkeyeInputAlert.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeSettingCell.h>
#import <MTHawkeye/MTHawkeyeSettingViewController.h>
#import <MTHawkeye/MTHawkeyeUtility.h>
#import <MTHawkeye/MTHawkeyeWebViewController.h>
#import <MTHawkeye/UIViewController+MTHawkeyeCurrentViewController.h>
#import <MTHawkeye/UIViewController+MTHawkeyeLayoutSupport.h>


MTHAllocationsReportSymbolicateHandler mthAllocationSymbolicsHandler = NULL;

static BOOL remoteSymbolicateProcess = NO;

@interface MTHAllocationsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) UITableView *tableView;

@property (assign, nonatomic) BOOL existCurrentRecord;

@property (strong, nonatomic) NSArray<NSString *> *historyDirNameList;

@property (strong, nonatomic) NSArray<MTHawkeyeSettingCellEntity *> *reportConfigCells;

@property (strong, nonatomic) UIActivityIndicatorView *waitingIndicatorView;
@property (assign, nonatomic) BOOL waitingRowSelectTaskComplete;


@end

@implementation MTHAllocationsViewController

- (void)loadView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.view = self.tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self buildReportConfigurationCells];

    [self loadData];
    [self reloadTableView];

    self.title = @"Allocations";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self reloadTableView];
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

- (void)reloadTableView {
    [self.tableView reloadData];
}

- (void)buildReportConfigurationCells {
    [self.tableView registerClass:[MTHawkeyeSettingCell class] forCellReuseIdentifier:@"mt-hawkeye-setting"];

    self.reportConfigCells = [self reportConfigSessionCellEntities];
}

- (void)loadData {
    self.existCurrentRecord = [MTHAllocations shared].existLoggingRecords;
    self.historyDirNameList = [self historyRecordDirectories];
}

// MARK: - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.reportConfigCells.count;
    } else if (section == 1) {
        if (self.existCurrentRecord)
            return 4;
        else
            return 1;
    } else if (section == 2) {
        return self.historyDirNameList.count;
    }
    return 0;
}

- (UITableViewCell *_Nonnull)tableView:(UITableView *_Nonnull)tableView cellForRowAtIndexPath:(NSIndexPath *_Nonnull)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"allocationsCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"memoryLeakedCell"];
    }

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (indexPath.section == 0) {
        cell = [self tableView:tableView configurationCellAtIndexPath:indexPath];
    } else if (indexPath.section == 1) {
        if (!self.existCurrentRecord) {
            cell.textLabel.text = @"Allocations Logger is OFF";
        } else {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Dump Allocations to console in line";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Generate Heap&VM report and flush to console"];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Dump Allocations to file in line";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Generate Heap&VM report and save to file"];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Dump Allocations to file in JSON";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Generate Heap&VM report and save to file"];
            } else if (indexPath.row == 3) {
                NSString *mem = [NSString stringWithFormat:@"%.0fMB", [MTHAllocations shared].assistantMmapMemoryUsed / 1024.f / 1024.f];
                cell.textLabel.text = [NSString stringWithFormat:@"Tool memory usage: %@", mem];
                cell.detailTextLabel.text = @"Used by hawkeye allocations";
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 2) {
        NSInteger idx = indexPath.row;
        if (idx < self.historyDirNameList.count) {
            cell.textLabel.text = self.historyDirNameList[idx];
            cell.detailTextLabel.text = nil;
            NSString *path = [self pathForHistoryAtIndex:idx];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    }
    return cell;
}

- (UITableViewCell *_Nonnull)tableView:(UITableView *_Nonnull)tableView configurationCellAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeSettingCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mt-hawkeye-setting" forIndexPath:indexPath];

    if (indexPath.row >= self.reportConfigCells.count)
        return cell;

    MTHawkeyeSettingCellEntity *model = self.reportConfigCells[indexPath.row];
    cell.model = model;
    return cell;
}

// MARK: UITableViewDelegate
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Report Configuration";
    } else if (section == 1) {
        return @"Running Session";
    } else if (section == 2) {
        return @"History Sessions";
    }
    return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"";
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (section == 0) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = @"Report Configuration";
    } else if (section == 1) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = @"Running Session";
    } else if (section == 2) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = @"History Sessions";
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.waitingRowSelectTaskComplete ? NO : YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        [self reportConfigDidSelectAtIndexPath:indexPath];
    } else if (indexPath.section == 1) {
        if (self.existCurrentRecord) {
            if (indexPath.row == 0) {
                [self flushCurrentSessionAllocationsRecordToConsole];
            } else if (indexPath.row == 1) {
                [self flushCurrentSessionAllocationsRecordToFileInJson:NO];
            } else if (indexPath.row == 2) {
                [self flushCurrentSessionAllocationsRecordToFileInJson:YES];
            }
        } else {
            [self gotoSetting];
        }
    } else if (indexPath.section == 2) {
        NSInteger idx = indexPath.row;
        if (idx < self.historyDirNameList.count) {
            NSString *path = [self pathForHistoryAtIndex:idx];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [self flushHistoryAllocationsRecordToFileAtPath:path];
            } else {
                // do nothing.
            }
        }
    }
}

- (void)reportConfigDidSelectAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.reportConfigCells.count)
        return;

    MTHawkeyeSettingCellEntity *viewModel = self.reportConfigCells[indexPath.row];

    if (![viewModel isKindOfClass:[MTHawkeyeSettingEditorCellEntity class]])
        return;

    MTHawkeyeSettingEditorCellEntity *editorModel = (MTHawkeyeSettingEditorCellEntity *)viewModel;

    [MTHawkeyeInputAlert
        showInputAlertWithTitle:editorModel.title
        messgage:editorModel.inputTips
        from:self
        textFieldSetupHandler:^(UITextField *_Nonnull textField) {
            textField.text = editorModel.setupValueHandler();
            textField.keyboardType = editorModel.editorKeyboardType;
        }
        confirmHandler:^(UITextField *_Nonnull textField) {
            NSString *newValue = textField.text;
            if (editorModel.valueChangedHandler(newValue)) {
                [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        cancelHandler:nil];
}

// MARK: - Allocations
- (void)flushCurrentSessionAllocationsRecordToConsole {
    [[MTHAllocations shared] generateReportAndFlushToConsole];
}

- (void)flushCurrentSessionAllocationsRecordToFileInJson:(BOOL)inJSONStyle {
    NSString *mallocReportRaw;
    NSString *vmReportRaw;
    if (![[MTHAllocations shared] existLoggingRecords]) {
        if (![MTHawkeyeUserDefaults shared].allocationsTraceOn) {
            [self guideToTurnOnAllocations];
            return;
        } else {
            mallocReportRaw = @"Empty DefaultMallocZone(Heap) record.";
            vmReportRaw = @"Empty vm(vmallocate/mmap ...) record.";
        }
    } else {
        [self showWaitingIndicator];

        if (inJSONStyle) {
            [[MTHAllocations shared] generateReportAndSaveToFileInJSON];
        } else {
            [[MTHAllocations shared] generateReportAndSaveToFile];
        }

        mallocReportRaw = [[MTHAllocations shared] mallocReportFileContent];
        vmReportRaw = [[MTHAllocations shared] vmReportFileContent];

        if (inJSONStyle && remoteSymbolicateProcess) {
            NSString *dyldInfo = [[MTHAllocations shared] dyldImagesContent];
            __weak __typeof(self) weakSelf = self;
            if (mthAllocationSymbolicsHandler) {
                mthAllocationSymbolicsHandler(mallocReportRaw, vmReportRaw, dyldInfo, ^(NSString *mallocReport, NSString *vmReport, NSError *error) {
                    [weakSelf hanlderSymbolicatedMallocResult:mallocReport vmReport:vmReport error:error];
                });
            } else {
                [self symbolicateWithMallocReport:mallocReportRaw
                                         vmReport:vmReportRaw
                                       dyldImages:dyldInfo
                                       completion:^(NSString *mallocReport, NSString *vmReport, NSError *error) {
                                           [weakSelf hanlderSymbolicatedMallocResult:mallocReport vmReport:vmReport error:error];
                                       }];
            }
            return;
        }
    }

    [self showFixedReportWithMallocReport:mallocReportRaw vmReport:vmReportRaw];
}

- (void)hanlderSymbolicatedMallocResult:(NSString *)mallocReport vmReport:(NSString *)vmReport error:(NSError *)error {
    [self hideWaitingIndicator];

    if (error) {
        [self showContent:[NSString stringWithFormat:@"%@", error]];
    } else {
        [self showFixedReportWithMallocReport:mallocReport vmReport:vmReport];
    }
}

- (NSString *)pathForHistoryAtIndex:(NSInteger)index {
    if (index >= self.historyDirNameList.count)
        return nil;

    NSString *dirName = self.historyDirNameList[index];
    NSString *path = [[MTHawkeyeUtility hawkeyeStoreDirectory] stringByAppendingPathComponent:dirName];
    path = [path stringByAppendingPathComponent:@"allocations"];
    return path;
}

- (void)flushHistoryAllocationsRecordToFileAtPath:(NSString *)historyRecordDir {
    if (![[NSFileManager defaultManager] fileExistsAtPath:historyRecordDir]) {
        [self showContent:@"Previous session data doesn't contain Allocation records, you should turn on it firstly."];
    } else {
        [self showWaitingIndicator];

        MTHAHistoryRecordReader *reader = [[MTHAHistoryRecordReader alloc] initWithRecordDir:historyRecordDir];
        CGFloat mallocThresholdInBytes = [MTHAllocations shared].mallocReportThresholdInBytes;
        CGFloat vmThresholdInBytes = [MTHAllocations shared].vmReportThresholdInBytes;
        [reader generateReportWithMallocThresholdInBytes:mallocThresholdInBytes vmThresholdInBytes:vmThresholdInBytes];

        NSString *mallocReportRaw = [reader mallocReportContent];
        NSString *vmReportRaw = [reader vmReportContent];
        NSString *dyldImagesInfo = [reader dyldImagesContent];

        if (remoteSymbolicateProcess && (mallocReportRaw.length > 0 || vmReportRaw.length > 0) && dyldImagesInfo.length > 0) {
            NSString *dyldInfo = [[MTHAllocations shared] dyldImagesContent];
            __weak __typeof(self) weakSelf = self;
            if (mthAllocationSymbolicsHandler) {
                mthAllocationSymbolicsHandler(mallocReportRaw, vmReportRaw, dyldInfo, ^(NSString *mallocReport, NSString *vmReport, NSError *error) {
                    [weakSelf hanlderHistorySymbolicatedMallocResult:mallocReport vmReport:vmReport historyRecordDir:historyRecordDir mallocThreshold:mallocThresholdInBytes vmThreshold:vmThresholdInBytes error:error];
                });
            } else {
                [self symbolicateWithMallocReport:mallocReportRaw
                                         vmReport:vmReportRaw
                                       dyldImages:dyldInfo
                                       completion:^(NSString *mallocReport, NSString *vmReport, NSError *error) {
                                           [weakSelf hanlderHistorySymbolicatedMallocResult:mallocReport vmReport:vmReport historyRecordDir:historyRecordDir mallocThreshold:mallocThresholdInBytes vmThreshold:vmThresholdInBytes error:error];
                                       }];
            }
            return;
        } else {
            if (mallocReportRaw.length == 0) {
                mallocReportRaw = @"Empty DefaultMallocZone(Heap) record.";
            }
            if (vmReportRaw.length == 0) {
                vmReportRaw = @"Empty vm(vmallocate/mmap ...) record.";
            }
            if (dyldImagesInfo.length == 0) {
                dyldImagesInfo = @"Empty dyld images record.";
            }
            [self showFixedHistoryReportWithMallocReport:mallocReportRaw
                                                vmReport:vmReportRaw
                                        historyRecordDir:historyRecordDir
                                         mallocThreshold:mallocThresholdInBytes
                                             vmThreshold:vmThresholdInBytes
                                          dyldImagesInfo:dyldImagesInfo];
        }
    }
}

- (void)hanlderHistorySymbolicatedMallocResult:(NSString *)mallocReport
                                      vmReport:(NSString *)vmReport
                              historyRecordDir:(NSString *)historyRecordDir
                               mallocThreshold:(NSInteger)mallocThresholdInBytes
                                   vmThreshold:(NSInteger)vmThresholdInBytes
                                         error:(NSError *)error {
    [self hideWaitingIndicator];

    if (error) {
        [self showContent:[NSString stringWithFormat:@"%@", error]];
    } else {
        [self showFixedHistoryReportWithMallocReport:mallocReport vmReport:vmReport historyRecordDir:historyRecordDir mallocThreshold:mallocThresholdInBytes vmThreshold:vmThresholdInBytes dyldImagesInfo:nil];
    }
}


- (void)showFixedReportWithMallocReport:(NSString *)mallocReport vmReport:(NSString *)vmReport {
    CGFloat mallocThreshold = [MTHAllocations shared].mallocReportThresholdInBytes / 1024.f;
    CGFloat vmThreshold = [MTHAllocations shared].vmReportThresholdInBytes / 1024.f;
    NSString *content = [NSString stringWithFormat:
                                      @"\n"
                                      @"[hawkeye] DefaultMallocZone(Heap) report: \n"
                                      @"[hawkeye] report threshold: %.2fKB \n\n"
                                      @"%@"
                                      @"\n\n ---------------------- \n\n"
                                      @"[hawkeye] vm(vmallocate/mmap ...) report: \n"
                                      @"[hawkeye] report threshold: %.2fKB \n\n"
                                      @"%@ \n"
                                      @"\n\n",
                                  mallocThreshold, mallocReport, vmThreshold, vmReport];
    [self showContent:content];
}

- (void)showFixedHistoryReportWithMallocReport:(NSString *)mallocReport
                                      vmReport:(NSString *)vmReport
                              historyRecordDir:(NSString *)historyRecordDir
                               mallocThreshold:(NSInteger)mallocThresholdInBytes
                                   vmThreshold:(NSInteger)vmThresholdInBytes
                                dyldImagesInfo:(NSString *)dyldImagesInfo {
    NSString *content = [NSString stringWithFormat:
                                      @"\n"
                                      @"[hawkeye] Record Dir: %@\n\n"
                                      @"[hawkeye] DefaultMallocZone(Heap) report: \n"
                                      @"[hawkeye] report threshold: %.2fKB \n\n"
                                      @"%@"
                                      @"\n\n ---------------------- \n\n"
                                      @"[hawkeye] vm(vmallocate/mmap ...) report: \n"
                                      @"[hawkeye] report threshold: %.2fKB \n\n"
                                      @"%@ \n"
                                      @"\n\n ---------------------- \n\n"
                                      @"[hawkeye] dyld images: \n"
                                      @"%@",
                                  historyRecordDir, mallocThresholdInBytes / 1024.f, mallocReport, vmThresholdInBytes / 1024.f, vmReport, dyldImagesInfo];
    [self showContent:content];
}

// MARK: - Assist

- (void)showWaitingIndicator {
    if (_waitingIndicatorView == nil) {
        CGRect frame = CGRectMake(0, 0, 120, 90);
        _waitingIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        _waitingIndicatorView.backgroundColor = [UIColor colorWithWhite:.15f alpha:.8f];
        _waitingIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        _waitingIndicatorView.layer.cornerRadius = 8.f;
        [self.tableView addSubview:_waitingIndicatorView];
    }

    CGRect mainBounds = [UIScreen mainScreen].bounds;
    CGPoint center = CGPointMake(CGRectGetWidth(mainBounds) / 2.f, CGRectGetHeight(mainBounds) / 2.f);
    center = [self.tableView convertPoint:center fromView:self.tableView.window];
    center.y -= 10.f;
    self.waitingIndicatorView.center = center;

    [self.waitingIndicatorView startAnimating];
    self.waitingRowSelectTaskComplete = YES;
}

- (void)hideWaitingIndicator {
    if (self.waitingIndicatorView) {
        [self.waitingIndicatorView stopAnimating];
        [self.waitingIndicatorView removeFromSuperview];
        self.waitingIndicatorView = nil;
    }
    self.waitingRowSelectTaskComplete = NO;
}

- (void)guideToTurnOnAllocations {
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:@"Allocations is OFF，you can turn on Allocations to record Heap/VM operations and its stacks" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Go to Setting"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                [weakSelf gotoSetting];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showContent:(NSString *)content {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self hideWaitingIndicator];

        MTHawkeyeWebViewController *vc = [[MTHawkeyeWebViewController alloc] initWithText:content];
        [self.navigationController pushViewController:vc animated:YES];
    });
}

// MARK: - Report Configuration Cells
- (NSArray<MTHawkeyeSettingCellEntity *> *)reportConfigSessionCellEntities {
    NSArray *cellModels = @[
        [MTHAllocationsSettingEntity mallocReportThresholdEditorCell],
        [MTHAllocationsSettingEntity vmReportThresholdEditorCell],
        [MTHAllocationsSettingEntity reportCategoryElementCountThresholdEditorCell],
        [self remoteSymbolicisSwitcherCell],
    ];
    return cellModels;
}

- (MTHawkeyeSettingSwitcherCellEntity *)remoteSymbolicisSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Remote Symbolics";
    entity.setupValueHandler = ^BOOL {
        return remoteSymbolicateProcess;
    };

    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != remoteSymbolicateProcess) {
            remoteSymbolicateProcess = newValue;
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

// MARK: - Default Symbolics service

- (BOOL)symbolicateWithMallocReport:(NSString *)mallocReportRaw
                           vmReport:(NSString *)vmReportRaw
                         dyldImages:(NSString *)dyldImages
                         completion:(void (^)(NSString *mallocReport, NSString *vmReport, NSError *error))completionHandler {

    NSMutableSet *toSymbolizeFrames = [NSMutableSet set];
    [toSymbolizeFrames addObjectsFromArray:[[self framesSetFromUnsymbolizeReport:mallocReportRaw] allObjects]];
    [toSymbolizeFrames addObjectsFromArray:[[self framesSetFromUnsymbolizeReport:vmReportRaw] allObjects]];
    if (toSymbolizeFrames.count == 0) {
        completionHandler(mallocReportRaw, vmReportRaw, nil);
        return YES;
    }

    if (dyldImages.length == 0) {
        completionHandler(mallocReportRaw, vmReportRaw, nil);
        return YES;
    }
    NSDictionary *dyldImagesInfoDict;
    {
        NSData *dyldImagesInfoData = [dyldImages dataUsingEncoding:NSUTF8StringEncoding];
        if (dyldImagesInfoData) {
            NSError *error;
            dyldImagesInfoDict = [NSJSONSerialization JSONObjectWithData:dyldImagesInfoData options:0 error:&error];
            if (error || ![dyldImagesInfoDict isKindOfClass:[NSDictionary class]]) {
                NSString *errMsg = [NSString stringWithFormat:@"convert dyld images file string to json failed: %@", error];
                MTHLogWarn(@"%@", errMsg);
                NSError *error = [self errorWithMsg:errMsg code:-1];
                completionHandler(mallocReportRaw, vmReportRaw, error);
                return NO;
            }
        }
    }

    [MTHStackFrameSymbolicsRemote
        symbolizeStackFrames:[toSymbolizeFrames allObjects]
         withDyldImagesInfos:dyldImagesInfoDict
           completionHandler:^(NSArray<NSDictionary<NSString *, NSString *> *> *_Nonnull remoteSymbolizedFrames, NSError *_Nonnull error) {
               NSMutableDictionary<NSString *, NSString *> *symbolizedFramesInDict = @{}.mutableCopy;
               [self formatRemoteSymolizedFramesDicts:remoteSymbolizedFrames intoOnlineFrame:symbolizedFramesInDict];

               NSString *mallocReportNew = [self replaceReportString:mallocReportRaw withFrameSymbolizeInfo:symbolizedFramesInDict];
               NSString *vmReportNew = [self replaceReportString:vmReportRaw withFrameSymbolizeInfo:symbolizedFramesInDict];
               completionHandler(mallocReportNew, vmReportNew, error);
           }];

    return YES;
}

- (NSSet<NSString *> *)framesSetFromUnsymbolizeReport:(NSString *)jsonStringReport {
    NSMutableSet *toSymbolizeFrames = [NSMutableSet set];
    NSDictionary *reportJson = [self jsonDictFromJsonString:jsonStringReport];
    if (reportJson && [reportJson isKindOfClass:[NSDictionary class]]) {
        NSArray *categories = reportJson[@"categories"];
        for (NSDictionary *category in categories) {
            NSArray *stacks = category[@"stacks"];
            if (![stacks isKindOfClass:[NSArray class]])
                continue;

            for (NSDictionary *stack in stacks) {
                NSArray *frames = stack[@"frames"];
                if (![frames isKindOfClass:[NSArray class]])
                    continue;

                for (NSString *frame in frames) {
                    [toSymbolizeFrames addObject:frame];
                }
            }
        }
    }
    return [toSymbolizeFrames copy];
}

- (NSString *)replaceReportString:(NSString *)reportRaw withFrameSymbolizeInfo:(NSDictionary<NSString *, NSString *> *)frameSymbolizeInfo {
    NSMutableString *result = [reportRaw mutableCopy];
    [frameSymbolizeInfo enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
        if (key.length > 0 && obj.length > 0) {
            [result replaceOccurrencesOfString:key withString:obj options:0 range:NSMakeRange(0, result.length)];
        }
    }];
    return [result copy];
}

- (NSDictionary *)jsonDictFromJsonString:(NSString *)jsonString {
    if (jsonString.length == 0)
        return nil;

    NSData *reportData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (reportData == nil)
        return nil;

    NSError *error = nil;
    NSDictionary *reportJson = [NSJSONSerialization JSONObjectWithData:reportData options:0 error:&error];
    if (error || ![reportJson isKindOfClass:[NSDictionary class]]) {
        MTHLogWarn(@"convert allocation report string to json failed: %@ \n string:%@", error, jsonString);
    }
    return reportJson;
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

- (NSError *)errorWithMsg:(NSString *)msg code:(NSInteger)code {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : msg};
    return [NSError errorWithDomain:@"com.meitu.hawkeye.allocations" code:code userInfo:userInfo];
}

// MARK: - Utils

- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = ((MTHawkeyeSettingFoldedCellEntity *)[MTHAllocationsHawkeyeUI settings]).foldedSections;
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Allocations" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSArray<NSString *> *)historyRecordDirectories {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:[MTHawkeyeUtility currentStoreDirectoryNameFormat]];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];

    NSMutableArray *historyDirList = [NSMutableArray array];

    NSString *hawkeyePath = [MTHawkeyeUtility hawkeyeStoreDirectory];
    NSArray<NSString *> *logDirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:hawkeyePath error:NULL];
    __block NSTimeInterval currentSession = [MTHawkeyeUtility appLaunchedTime];
    [logDirectories enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSDate *createDate = [dateFormatter dateFromString:obj];
        NSTimeInterval timeDiff = currentSession - [createDate timeIntervalSince1970];
        if (timeDiff > 1) {
            [historyDirList addObject:obj];
        }
    }];
    return [historyDirList copy];
}

@end
