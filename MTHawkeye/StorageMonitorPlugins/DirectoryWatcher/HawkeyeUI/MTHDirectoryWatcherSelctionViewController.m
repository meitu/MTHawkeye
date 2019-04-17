//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/15
// Created by: David.Dai
//


#import "MTHDirectoryWatcherSelctionViewController.h"
#import "MTHDirectoryWatcherSelctionTableViewCell.h"
#import "MTHawkeyeInputAlert.h"

#import "MTHDirectoryTree.h"
#import "MTHDirectoryWatcher.h"
#import "MTHawkeyeUserDefaults+DirectorWatcher.h"

@interface MTHDirectoryWatcherSelctionViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<MTHDirectoryTree *> *dataSource;
@property (nonatomic, strong) NSArray<MTHDirectoryTree *> *watchingDataSource;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL showWatching;
@end

@implementation MTHDirectoryWatcherSelctionViewController

- (instancetype)initWithRootData:(NSArray *)dataSource showWatching:(BOOL)showWatching {
    if (self = [super init]) {
        _dataSource = dataSource;
        _showWatching = showWatching;
        NSString *title = [[_dataSource firstObject].relativePath stringByDeletingLastPathComponent];
        self.title = title.length ? title : @"SandBox";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self getWatchingDataSource];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self getWatchingDataSource];
    [self.tableView reloadData];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)getWatchingDataSource {
    if (!_showWatching) {
        return;
    }
    NSArray *watchingPath = [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSString *path in watchingPath) {
        [data addObject:[[MTHDirectoryTree alloc] initWithRelativePath:path]];
    }
    self.watchingDataSource = data;
}

#pragma mark - TableView Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_showWatching) {
        return 2;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0 && _showWatching) {
        return @"Watching Paths";
    }
    return @"Directory Tree";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0 && _showWatching) {
        return self.watchingDataSource.count;
    }
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && _showWatching) {
        MTHDirectoryTree *watchingData = [self.watchingDataSource objectAtIndex:indexPath.row];
        NSNumber *limitMB = [[MTHawkeyeUserDefaults shared].directoryWatcherFoldersLimitInMB objectForKey:watchingData.relativePath];
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MTHDirectoryWatcherSelectCell1"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MTHDirectoryWatcherSelectCell1"];
        }
        float folderSize = [MTHDirectoryWatcher fileSizeAtPath:watchingData.absolutePath] / 1024.0 / 1024.0;
        NSString *folderSizeStr = [NSString stringWithFormat:@"%0.2fMB", folderSize];
        NSString *string = [NSString stringWithFormat:@"%@ (%@)", watchingData.relativePath, folderSizeStr];
        cell.textLabel.text = string;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.0fMB", limitMB.floatValue];
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        return cell;
    }

    MTHDirectoryWatcherSelctionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MTHDirectoryWatcherSelectCell"];
    if (!cell) {
        cell = [[MTHDirectoryWatcherSelctionTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"MTHDirectoryWatcherSelectCell"];
    }

    MTHDirectoryTree *data = [self.dataSource objectAtIndex:indexPath.row];
    cell.path = data.relativePath;
    cell.haveChild = data.childTree.count ? YES : NO;
    __weak typeof(self) weakSelf = self;
    cell.switchBlock = ^{
        [weakSelf getWatchingDataSource];
        [weakSelf.tableView reloadData];
    };
    NSArray<NSString *> *wathcingPath = [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath;
    cell.isWatching = [wathcingPath containsObject:data.relativePath] ? YES : NO;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHDirectoryWatcherSelctionTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell setSelected:NO animated:YES];
    if (indexPath.section == 0 && _showWatching) {
        MTHDirectoryTree *watchingData = [self.watchingDataSource objectAtIndex:indexPath.row];
        NSNumber *limitMB = [[MTHawkeyeUserDefaults shared].directoryWatcherFoldersLimitInMB objectForKey:watchingData.relativePath];
        if (indexPath.section == 0) {
            [MTHawkeyeInputAlert showInputAlertWithTitle:@"Warning Threshold"
                messgage:@""
                from:self
                textFieldSetupHandler:^(UITextField *_Nonnull textField) {
                    textField.text = [NSString stringWithFormat:@"%.2f", limitMB.floatValue];
                    textField.placeholder = [NSString stringWithFormat:@"limit in %0.0fMB", limitMB.floatValue];
                    textField.keyboardType = UIKeyboardTypeNumberPad;
                }
                confirmHandler:^(UITextField *_Nonnull textField) {
                    NSString *text = textField.text;
                    if (text.length && (text.floatValue != limitMB.floatValue)) {
                        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:[MTHawkeyeUserDefaults shared].directoryWatcherFoldersLimitInMB];
                        [dic setObject:@(text.floatValue) forKey:watchingData.relativePath];
                        [MTHawkeyeUserDefaults shared].directoryWatcherFoldersLimitInMB = dic;
                        [self.tableView reloadData];
                    }
                }
                cancelHandler:nil];
        }
        return;
    }


    MTHDirectoryTree *data = [self.dataSource objectAtIndex:indexPath.row];
    if (data.childTree.count) {
        MTHDirectoryWatcherSelctionViewController *childVC = [[MTHDirectoryWatcherSelctionViewController alloc] initWithRootData:data.childTree
                                                                                                                    showWatching:NO];
        if (self.navigationController) {
            [self.navigationController pushViewController:childVC animated:YES];
        } else {
            [self presentViewController:childVC animated:YES completion:nil];
        }
    }
}
@end
