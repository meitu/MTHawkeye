//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import "MTHNetworkMonitorViewController.h"
#import "MTHNetworkHawkeyeUI.h"
#import "MTHNetworkHistoryViewCell.h"
#import "MTHNetworkMonitorFilterViewController.h"
#import "MTHNetworkMonitorViewModel.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkRecordsStorage.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkToolsViewController.h"
#import "MTHNetworkTransaction.h"
#import "MTHNetworkTransactionDetailTableViewController.h"
#import "MTHNetworkTransactionsURLFilter.h"
#import "MTHNetworkWaterfallViewController.h"
#import "MTHPopoverViewController.h"
#import "MTHawkeyeSettingViewController.h"
#import "MTHawkeyeUserDefaults+NetworkMonitor.h"
#import "UITableView+MTHEmptyTips.h"


@interface MTHNetworkMonitorViewController () <MTHNetworkHistoryViewCellDelegate,
    MTHNetworkMonitorFilterDelegate,
    MTHNetworkRecorderDelegate,
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchResultsUpdating,
    UISearchControllerDelegate,
    UISearchBarDelegate>

@property (nonatomic, strong) MTHNetworkMonitorViewModel *viewModel;

@property (nonatomic, strong) MTHNetworkWaterfallViewController *waterfallViewController;

@property (nonatomic, strong) MTHNetworkMonitorFilterViewController *filterVC;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL searchControllerWasActive;
@property (nonatomic, assign) BOOL searchControllerSearchFieldWasFirstResponder;

@property (nonatomic, strong) UIView *waterfallPlaceView;
@property (nonatomic, strong) UITableView *historyTableView;
@property (nonatomic, strong) UILabel *headerLabel; // historyTableView HeaderView Label

@property (nonatomic, assign) BOOL loadingData;
@property (nonatomic, assign) BOOL rowInsertInProgress;
@property (nonatomic, strong) NSMutableArray<MTHNetworkTransaction *> *incomeTransactionsNew;

@end


@implementation MTHNetworkMonitorViewController

- (void)dealloc {
    @autoreleasepool {
        self.viewModel = nil;

        [[MTHNetworkTaskInspector shared] releaseNetworkTaskInspectorElement];
        [[MTHNetworkRecorder defaultRecorder] removeDelegate:self];
    }
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewModel = [[MTHNetworkMonitorViewModel alloc] init];
    self.incomeTransactionsNew = @[].mutableCopy;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.delegate = self;
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.placeholder = @"eg:\"d s f \" repeatedly failure request";
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.searchBar.showsSearchResultsButton = YES;
    self.searchController.searchBar.backgroundColor = [UIColor colorWithRed:243.0 / 255 green:242.0 / 255 blue:242.0 / 255 alpha:1.0];
    [self.view addSubview:self.searchController.searchBar];
    self.definesPresentationContext = YES;

    CGFloat top = self.searchController.searchBar.bounds.size.height;
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat headerHeight = 140;
    CGRect headerFrame = CGRectMake(0, top, width, headerHeight);
    self.waterfallPlaceView = [[UIView alloc] initWithFrame:headerFrame];
    self.waterfallPlaceView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.waterfallPlaceView];

    self.waterfallViewController = [[MTHNetworkWaterfallViewController alloc] initWithViewModel:self.viewModel];
    [self.waterfallViewController willMoveToParentViewController:self];
    [self addChildViewController:self.waterfallViewController];
    self.waterfallViewController.view.frame = self.waterfallPlaceView.bounds;
    [self.waterfallPlaceView addSubview:self.waterfallViewController.view];
    [self.waterfallViewController didMoveToParentViewController:self];

    top += headerFrame.size.height;

    CGFloat listHeight = self.view.bounds.size.height - top - headerHeight;
    CGRect listFrame = CGRectMake(0, top, width, listHeight);
    self.historyTableView = [[UITableView alloc] initWithFrame:listFrame style:UITableViewStylePlain];
    self.historyTableView.delegate = self;
    self.historyTableView.dataSource = self;

    [self.view addSubview:self.historyTableView];

    [[MTHNetworkRecorder defaultRecorder] addDelegate:self];

    [self loadTransactions];

    //    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Tools" style:UIBarButtonItemStylePlain target:self action:@selector(toolsBtnTapped)];
}

- (void)loadTransactions {
    if (!self.headerLabel) {
        self.headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, self.view.frame.size.width - 20, 30)];
    }
    self.headerLabel.text = @"Loading ...";
    self.loadingData = YES;

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [weakSelf.viewModel loadTransactionsWithInspectComoletion:^{
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [weakSelf.historyTableView reloadData];
                weakSelf.loadingData = NO;
            });
        }];

        // 侦测网络请求中的可改进项
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [weakSelf focusOnFirstRowIfPossible];

            [weakSelf reloadHistoryTableView];

            NSArray *transactions = self.searchController.isActive ? self.viewModel.filteredNetworkTransactions : self.viewModel.networkTransactions;
            NSInteger totalRequest = 0;
            NSInteger totalResponse = 0;
            for (MTHNetworkTransaction *transaction in transactions) {
                totalRequest += transaction.requestLength;
                totalResponse += transaction.responseLength;
            }
            NSInteger total = totalRequest + totalResponse;

            self.headerLabel.text = [NSString stringWithFormat:@"⇅ %@, ↑ %@, ↓ %@",
                                              [NSByteCountFormatter stringFromByteCount:total
                                                                             countStyle:NSByteCountFormatterCountStyleBinary],
                                              [NSByteCountFormatter stringFromByteCount:totalRequest
                                                                             countStyle:NSByteCountFormatterCountStyleBinary],
                                              [NSByteCountFormatter stringFromByteCount:totalResponse
                                                                             countStyle:NSByteCountFormatterCountStyleBinary]];
        });
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.searchController.isActive) {
        [self.view setNeedsLayout];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if (!self.view.window && self.searchController.isActive) {
        [self.searchController setActive:NO];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat top = [self p_navigationBarTopLayoutGuide].length;

    UISearchBar *searchBar = self.searchController.searchBar;
    if (self.searchController.isActive) {
        CGRect searchBarFrame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
        searchBar.frame = searchBarFrame;
    } else {
        CGRect searchBarFrame = CGRectMake(0, top, self.view.bounds.size.width, 44);
        searchBar.frame = searchBarFrame;
    }

    top += searchBar.frame.size.height;

    CGRect waterfallFrame = CGRectMake(0, top, self.view.bounds.size.width, self.waterfallPlaceView.bounds.size.height);
    self.waterfallPlaceView.frame = waterfallFrame;
    [self.waterfallViewController updateContentInset];

    top += waterfallFrame.size.height;
    CGRect listFrame = CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top);
    self.historyTableView.frame = listFrame;

    CGFloat left = 10.f;
    CGFloat maxWidth = CGRectGetWidth(self.view.bounds);
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11, *)) {
        left += self.view.safeAreaInsets.left;
        maxWidth -= (left + self.view.safeAreaInsets.right);
    }
#endif
    self.headerLabel.frame = CGRectMake(left, 0, maxWidth - left, 30);
}

- (id<UILayoutSupport>)p_navigationBarTopLayoutGuide {
    UIViewController *cur = self;
    while (cur.parentViewController && ![cur.parentViewController isKindOfClass:UINavigationController.class]) {
        cur = cur.parentViewController;
    }

    return cur.topLayoutGuide;
}

// MARK: - MTHNetworkRecorder

- (void)recorderWantCacheNewTransaction:(MTHNetworkTransaction *)transaction {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        @synchronized(self.incomeTransactionsNew) {
            [self.incomeTransactionsNew insertObject:transaction atIndex:0];
        }

        [self tryUpdateTransactions];
    });
}

- (void)tryUpdateTransactions {
    if (self.loadingData || self.rowInsertInProgress || self.searchController.isActive) {
        return;
    }

    NSInteger addedRowCount = 0;
    @synchronized(self.incomeTransactionsNew) {
        if (self.incomeTransactionsNew.count == 0)
            return;

        addedRowCount = [self.incomeTransactionsNew count];
        [self.viewModel incomeNewTransactions:[self.incomeTransactionsNew copy]
                            inspectCompletion:^{
                                // simply ignore to update advices tips.
                            }];
        [self.incomeTransactionsNew removeAllObjects];
    }

    if (addedRowCount != 0 && !self.viewModel.isPresentingSearch) {
        // 头部插入了新的请求记录，更新焦点
        NSInteger fixFocusIndex = self.viewModel.requestIndexFocusOnCurrently;
        [self.viewModel focusOnTransactionWithRequestIndex:fixFocusIndex];
        [self.waterfallViewController reloadData];

        // insert animation if we're at the top.
        if (self.historyTableView.contentOffset.y <= 0.f) {
            [CATransaction begin];

            self.rowInsertInProgress = YES;
            [CATransaction setCompletionBlock:^{
                self.rowInsertInProgress = NO;
                [self tryUpdateTransactions];
            }];

            NSMutableArray *indexPathsToReload = [NSMutableArray array];
            for (NSInteger row = 0; row < addedRowCount; row++) {
                [indexPathsToReload addObject:[NSIndexPath indexPathForRow:row inSection:0]];
            }
            [self.historyTableView insertRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationAutomatic];

            [CATransaction commit];
        } else {
            // Maintain the user's position if they've scrolled down.
            CGSize existingContentSize = self.historyTableView.contentSize;
            [self.historyTableView reloadData];
            CGFloat contentHeightChange = self.historyTableView.contentSize.height - existingContentSize.height;
            self.historyTableView.contentOffset = CGPointMake(self.historyTableView.contentOffset.x, self.historyTableView.contentOffset.y + contentHeightChange);
        }
    }
}

- (void)recorderWantCacheTransactionAsUpdated:(MTHNetworkTransaction *)transaction currentState:(MTHNetworkTransactionState)state {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (MTHNetworkHistoryViewCell *cell in [self.historyTableView visibleCells]) {
            if ([cell.transaction isEqual:transaction]) {
                [cell setNeedsLayout];

                if (transaction.transactionState == MTHNetworkTransactionStateFailed || transaction.transactionState == MTHNetworkTransactionStateFinished) {
                    [self.viewModel focusOnTransactionWithRequestIndex:self.viewModel.requestIndexFocusOnCurrently];
                    [self.waterfallViewController reloadData];
                }
                break;
            }
        }
    });
}

// MARK: -
- (void)focusOnFirstRowIfPossible {
    if (self.viewModel.networkTransactions.count > 0) {
        [self focusOnTransactionAtRowIndex:0];
    }
}

- (void)focusOnTransactionAtRowIndex:(NSInteger)index {
    MTHNetworkTransaction *focusedTrans = nil;
    if (self.searchController.isActive) {
        if (self.viewModel.filteredNetworkTransactions.count <= index)
            return;

        focusedTrans = self.viewModel.filteredNetworkTransactions[index];
    } else {
        if (self.viewModel.networkTransactions.count <= index)
            return;

        focusedTrans = self.viewModel.networkTransactions[index];
    }

    [self.viewModel focusOnTransactionWithRequestIndex:focusedTrans.requestIndex];
    [self.waterfallViewController reloadData];
    [self.historyTableView reloadData];
}

// MARK: - UITableViewDataSource

- (void)reloadHistoryTableView {
    if (![MTHawkeyeUserDefaults shared].networkMonitorOn) {
        [self.historyTableView mthawkeye_setFooterViewWithEmptyTips:@"Network tracing is off"
                                                            tipsTop:80.f
                                                             button:@"Go to Setting"
                                                          btnTarget:self
                                                          btnAction:@selector(gotoSetting)];
    } else {
        BOOL isRecordEmpty = NO;
        if (self.searchController.isActive)
            isRecordEmpty = [self.viewModel.filteredNetworkTransactions count] == 0;
        else
            isRecordEmpty = [self.viewModel.networkTransactions count] == 0;

        if (isRecordEmpty) {
            // show filter if
            NSString *filterDesc = [self.viewModel.filter filterDescription];
            if (filterDesc.length > 0) {
                NSString *tips = [NSString stringWithFormat:@"Empty Records\n\n%@", filterDesc];
                [self.historyTableView mthawkeye_setFooterViewWithEmptyTips:tips tipsTop:60.f];
            } else {
                [self.historyTableView mthawkeye_setFooterViewWithEmptyTips:@"Empty Records" tipsTop:80.f];
            }
        } else {
            self.historyTableView.tableFooterView = [UIView new];
        }
    }

    [self.historyTableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.searchController.isActive) {
        return [self.viewModel.filteredNetworkTransactions count];
    } else {
        return [self.viewModel.networkTransactions count];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [MTHNetworkHistoryViewCell preferredCellHeight];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHNetworkHistoryViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MTNetworkHistoryViewCellIdentifier];
    if (cell == nil) {
        cell = [[MTHNetworkHistoryViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MTNetworkHistoryViewCellIdentifier];
        cell.delegate = self;
    }

    NSArray *transactions = nil;
    if (self.searchController.isActive) {
        transactions = self.viewModel.filteredNetworkTransactions;
        cell.warningAdviceTypeIDs = self.viewModel.warningAdviceTypeIDs;
    } else {
        transactions = self.viewModel.networkTransactions;
        cell.warningAdviceTypeIDs = nil;
    }

    if (indexPath.row < transactions.count) {
        cell.transaction = transactions[indexPath.row];
        cell.advices = [self.viewModel advicesForTransaction:cell.transaction];
        if (cell.transaction.requestIndex == self.viewModel.requestIndexFocusOnCurrently) {
            cell.status = MTHNetworkHistoryViewCellStatusOnFocus;
        } else if ([self.viewModel.currentOnViewIndexArray containsObject:@(cell.transaction.requestIndex)]) {
            cell.status = MTHNetworkHistoryViewCellStatusOnWaterfall;
        } else {
            cell.status = MTHNetworkHistoryViewCellStatusDefault;
        }
    }

    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (!self.headerLabel) {
        self.headerLabel = [[UILabel alloc] init];
    }
    self.headerLabel.textColor = [UIColor colorWithWhite:0.0667 alpha:1];
    self.headerLabel.font = [UIFont systemFontOfSize:12.0];
    self.headerLabel.textAlignment = NSTextAlignmentLeft;
    self.headerLabel.numberOfLines = 1;
    UIView *headerView = [[UIView alloc] init];
    [headerView addSubview:self.headerLabel];
    headerView.backgroundColor = [UIColor colorWithRed:243.0 / 255 green:242.0 / 255 blue:242.0 / 255 alpha:1.0];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30.0;
}

// MARK: - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self focusOnTransactionAtRowIndex:indexPath.row];
}

// MARK: MTHNetworkHistoryViewCellDelegate
- (void)mt_networkHistoryViewCellDidTappedDetail:(MTHNetworkHistoryViewCell *)cell {
    MTHNetworkTransactionDetailTableViewController *detailViewController = [[MTHNetworkTransactionDetailTableViewController alloc] init];
    detailViewController.transaction = cell.transaction;
    detailViewController.advices = [self.viewModel advicesForTransaction:cell.transaction];
    [self.navigationController pushViewController:detailViewController animated:YES];
}

// MARK: - Menu Actions

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        MTHNetworkTransaction *transaction = [self transactionAtIndexPath:indexPath inTableView:tableView];
        NSString *requestURLString = transaction.request.URL.absoluteString ?: @"";
        [[UIPasteboard generalPasteboard] setString:requestURLString];
    }
}

- (MTHNetworkTransaction *)transactionAtIndexPath:(NSIndexPath *)indexPath inTableView:(UITableView *)tableView {
    return self.searchController.isActive ? self.viewModel.filteredNetworkTransactions[indexPath.row] : self.viewModel.networkTransactions[indexPath.row];
}

// MARK: - Action
- (void)toolsBtnTapped {
    MTHNetworkToolsViewController *vc = [[MTHNetworkToolsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

// MARK: - UISearchBarDelegate
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar {
    [self.searchController setActive:YES];
    // 弹出过滤选项
    if (!self.filterVC) {
        MTHNetworkMonitorFilterViewController *filterVC = [[MTHNetworkMonitorFilterViewController alloc] init];
        filterVC.filterDelegate = self;
        self.filterVC = filterVC;
    }
    MTHPopoverViewController *popoverVC = [[MTHPopoverViewController alloc] initWithContentViewController:self.filterVC fromSourceView:self.view];

    // 设为系统默认样式
    [popoverVC.navigationBar setBarTintColor:nil];
    [popoverVC.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [popoverVC.navigationBar setShadowImage:nil];
    [popoverVC.navigationBar setTitleTextAttributes:nil];

    [self presentViewController:popoverVC
                       animated:YES
                     completion:^{
                         [searchBar resignFirstResponder];
                     }];
}

// MARK: - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self updateSearchResults];
}

- (void)updateSearchResults {
    NSString *searchString = self.searchController.searchBar.text;
    __weak typeof(self) weak_self = self;
    [self.viewModel updateSearchResultsWithText:searchString
                                     completion:^{
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             [weak_self reloadHistoryTableView];
                                         });
                                     }];
}

// MARK: - UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    self.viewModel.isPresentingSearch = YES;
}

- (void)didPresentSearchController:(UISearchController *)searchController {
    self.viewModel.isPresentingSearch = NO;

    UIView *searchBarContainer = searchController.searchBar.superview;
    UIView *searchBar = searchController.searchBar;
    //
    if (!CGPointEqualToPoint(searchBarContainer.frame.origin, CGPointZero)) {
        CGFloat top = [self p_navigationBarTopLayoutGuide].length;
        CGRect frame = CGRectMake(0, top, searchBarContainer.bounds.size.width, searchBarContainer.bounds.size.height);
        searchBarContainer.frame = frame;
    }
    if (!CGPointEqualToPoint(searchBar.frame.origin, CGPointZero)) {
        CGRect frame = CGRectMake(0, 0, searchBar.bounds.size.width, searchBar.bounds.size.height);
        searchBar.frame = frame;
    }
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    [self.historyTableView reloadData];
}

// MARK: - MTHNetworkMonitorFilterDelegate

- (void)filterUpdatedWithStatusCodes:(MTHNetworkTransactionStatusCode)statusCodes
                         inspections:(NSArray<MTHNetworkTaskInspectionWithResult *> *)inspections
                               hosts:(NSArray<NSString *> *)hosts {
    self.viewModel.filter.statusFilter = statusCodes;
    self.viewModel.filter.hostFilter = hosts;
    self.viewModel.warningAdviceTypeIDs = [self adviceTypeIDsInInspections:inspections];
    [self updateSearchResults];
}

- (NSSet<NSString *> *)adviceTypeIDsInInspections:(NSArray<MTHNetworkTaskInspectionWithResult *> *)inspections {
    NSMutableSet<NSString *> *adviceTypeIDs = [NSMutableSet set];
    for (MTHNetworkTaskInspectionWithResult *inspection in inspections) {
        for (MTHNetworkTaskAdvice *advice in inspection.advices) {
            [adviceTypeIDs addObject:advice.typeId];
        }
    }
    return adviceTypeIDs;
}

// MARK: - Utils

- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = [(MTHawkeyeSettingFoldedCellEntity *)[MTHNetworkHawkeyeSettingUI settings] foldedSections];
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Network Settings" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
