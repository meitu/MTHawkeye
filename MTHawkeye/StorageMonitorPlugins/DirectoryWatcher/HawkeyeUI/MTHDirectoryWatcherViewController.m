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


#import "MTHDirectoryWatcherViewController.h"
#import "MTHDirectoryWatcherHawkeyeUI.h"
#import "MTHawkeyeSettingViewController.h"

#import <objc/runtime.h>
#import "MTHDirectoryTree.h"
#import "MTHDirectoryWatcher.h"

#import "MTHawkeyeUserDefaults+DirectorWatcher.h"
#import "UIViewController+MTHawkeyeLayoutSupport.h"

#import <FLEX/FLEXFileBrowserController.h>
#import <FLEX/FLEXImagePreviewViewController.h>
#import <FLEX/FLEXTableListViewController.h>
#import <FLEX/FLEXUtility.h>
#import <FLEX/FLEXWebViewController.h>

@interface MTHDirectoryWatcherViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<MTHDirectoryTree *> *dataSource;
@property (nonatomic, strong) NSArray<NSString *> *homeContentPaths;
@end

@implementation MTHDirectoryWatcherViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self getDataSource];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self getDataSource];
    [self.tableView reloadData];
    [self.view setNeedsLayout];
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

- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)getDataSource {
    NSArray *watchingPath = [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSString *path in watchingPath) {
        [data addObject:[[MTHDirectoryTree alloc] initWithRelativePath:path]];
    }
    self.dataSource = data;

    NSArray *homeContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSHomeDirectory() error:nil];
    NSMutableArray *homePaths = [NSMutableArray array];
    for (NSString *content in homeContent) {
        [homePaths addObject:[NSHomeDirectory() stringByAppendingPathComponent:content]];
    }
    self.homeContentPaths = homePaths;
}

#pragma mark - TableView Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"SandBox Home";
        case 1:
            return @"Watching Directory";
        case 2:
            return @"More Option";
        default:
            return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return self.homeContentPaths.count;
        case 1:
            return self.dataSource.count;
        case 2:
            return 1;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MTHDirectoryWatcherCell0"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MTHDirectoryWatcherCell0"];
        }
        cell.textLabel.text = [[self.homeContentPaths objectAtIndex:indexPath.row] lastPathComponent];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    if (indexPath.section == 1) {
        MTHDirectoryTree *data = [self.dataSource objectAtIndex:indexPath.row];
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MTHDirectoryWatcherCell1"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MTHDirectoryWatcherCell1"];
        }
        float folderSize = [MTHDirectoryWatcher fileSizeAtPath:data.absolutePath] / 1024.0 / 1024.0;
        NSString *folderSizeStr = [NSString stringWithFormat:@"%0.2fMB", folderSize];
        NSString *string = [NSString stringWithFormat:@"%@ (%@)", data.relativePath, folderSizeStr];
        cell.textLabel.text = string;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    if (indexPath.section == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MTHDirectoryWatcherCell2"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MTHDirectoryWatcherCell2"];
        }
        cell.textLabel.text = @"Storage Setting";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell setSelected:NO animated:YES];

    if (indexPath.section == 0) {
        NSString *path = [self.homeContentPaths objectAtIndex:indexPath.row];
        [self presentFlexFileBrowserWithPath:path];
    }

    if (indexPath.section == 1) {
        MTHDirectoryTree *data = [self.dataSource objectAtIndex:indexPath.row];
        [self presentFlexFileBrowserWithPath:data.absolutePath];
    }

    if (indexPath.section == 2) {
        MTHawkeyeSettingTableEntity *entry = [[MTHawkeyeSettingTableEntity alloc] init];
        entry.sections = [(MTHawkeyeSettingFoldedCellEntity *)[MTHDirectoryWatcherHawkeyeUI settings] foldedSections];
        MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Storage" viewModelEntity:entry];
        if (self.navigationController) {
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            [self presentViewController:vc animated:YES completion:nil];
        }
    }
}

- (void)presentFlexFileBrowserWithPath:(NSString *)fullPath {
    BOOL isDir = NO;
    BOOL fileExist = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];
    if (!fileExist) {
        return;
    }

    NSString *subpath = [fullPath lastPathComponent];
    NSString *pathExtension = [subpath pathExtension];
    UIViewController *vc = nil;
    if (isDir) {
        vc = [[FLEXFileBrowserController alloc] initWithPath:fullPath];
    } else if ([@[@"jpg", @"jpeg", @"png", @"gif", @"tiff", @"tif"] containsObject:pathExtension]) {
        UIImage *image = [UIImage imageWithContentsOfFile:fullPath];
        vc = [FLEXImagePreviewViewController forImage:image];
    } else {
        // Special case keyed archives, json, and plists to get more readable data.
        NSString *prettyString = nil;
        if ([pathExtension isEqual:@"archive"] || [pathExtension isEqual:@"coded"]) {
            prettyString = [[NSKeyedUnarchiver unarchiveObjectWithFile:fullPath] description];
        } else if ([pathExtension isEqualToString:@"json"]) {
            prettyString = [FLEXUtility prettyJSONStringFromData:[NSData dataWithContentsOfFile:fullPath]];
        } else if ([pathExtension isEqualToString:@"plist"]) {
            NSData *fileData = [NSData dataWithContentsOfFile:fullPath];
            prettyString = [[NSPropertyListSerialization propertyListWithData:fileData options:0 format:NULL error:NULL] description];
        }

        if ([prettyString length] > 0) {
            vc = [[FLEXWebViewController alloc] initWithText:prettyString];
        } else if ([FLEXWebViewController supportsPathExtension:pathExtension]) {
            vc = [[FLEXWebViewController alloc] initWithURL:[NSURL fileURLWithPath:fullPath]];
        } else if ([FLEXTableListViewController supportsExtension:subpath.pathExtension]) {
            vc = [[FLEXTableListViewController alloc] initWithPath:fullPath];
        } else {
            NSString *fileString = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:NULL];
            if ([fileString length] > 0) {
                vc = [[FLEXWebViewController alloc] initWithText:fileString];
            }
        }
    }

    if (vc) {
        vc.title = [subpath lastPathComponent];
        if (self.navigationController) {
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            [self presentViewController:vc animated:YES completion:nil];
        }
    }
}
@end
