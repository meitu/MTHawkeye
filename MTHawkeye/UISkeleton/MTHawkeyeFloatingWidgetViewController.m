//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#import "MTHawkeyeFloatingWidgetViewController.h"

#import "MTHMonitorView.h"
#import "MTHMonitorViewCell.h"
#import "MTHMonitorViewConfiguration.h"
#import "MTHUISkeletonUtility.h"
#import "MTHawkeyeFloatingWidgets.h"

BOOL mthawkeye_disableRotatingAnimation = NO;

@interface MTHawkeyeFloatingWidgetViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) MTHMonitorView *monitorView;

@end

@implementation MTHawkeyeFloatingWidgetViewController

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view addSubview:self.monitorView];
    [self.monitorView attachToEdgeAndSavePosition];
}

- (void)reloadData {
    CGFloat rowCount = [self.datasource floatingWidgetCellCount];
    CGFloat monitorHeight = MTHMonitorViewConfiguration.monitorCellHeight * rowCount;
    CGPoint frameOrigin = self.monitorView.frame.origin;
    CGRect frame = CGRectMake(frameOrigin.x, frameOrigin.y, MTHMonitorViewConfiguration.monitorWidth, monitorHeight);
    self.monitorView.frame = frame;

    [self.monitorView.tableView reloadData];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];

    [self.monitorView attachToEdgeAndSavePosition];
}

// MARK: - Actions
- (void)monitorViewDidTapped:(UITapGestureRecognizer *)tapGR {
    if (tapGR.state == UIGestureRecognizerStateRecognized) {
        [self.delegate floatingWidgetDidTapped];
    }
}

// MAKR: - MTHawkeyeFloatingWidgetsDataDelegate
- (void)floatingWidgetsUpdated {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self reloadData];
    });
}

// MARK: - UITableViewDatasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.datasource floatingWidgetCellCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHMonitorViewCell *cell = [self.datasource floatingWidgetCellAtIndex:indexPath.row];
    if (cell) {
        return cell;
    }

    cell = [tableView dequeueReusableCellWithIdentifier:@"hawkeye-floating-widget"];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return MTHMonitorViewConfiguration.monitorCellHeight;
}

// MARK: - Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    if (mthawkeye_disableRotatingAnimation) {
        // just disable the rotate animation here. (may effect the App's own appearance)
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [coordinator
            animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {

            }
            completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                [CATransaction commit];
            }];
    }
}

// MARK: - getter
- (MTHMonitorView *)monitorView {
    if (_monitorView == nil) {
        CGPoint pt = MTHMonitorViewConfiguration.monitorInitPosition;
        CGRect frame = CGRectMake(pt.x, pt.y, MTHMonitorViewConfiguration.monitorWidth, 0);
        _monitorView = [[MTHMonitorView alloc] initWithFrame:frame];
        _monitorView.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.8];
        _monitorView.tableView.dataSource = self;
        _monitorView.tableView.delegate = self;
        _monitorView.tableView.estimatedRowHeight = MTHMonitorViewConfiguration.monitorCellHeight;
        _monitorView.tableView.rowHeight = MTHMonitorViewConfiguration.monitorCellHeight;
        [_monitorView.tableView registerClass:[MTHMonitorViewCell class] forCellReuseIdentifier:@"hawkeye-floating-widget"];

        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(monitorViewDidTapped:)];
        [_monitorView addGestureRecognizer:tapGesture];
    }
    return _monitorView;
}

@end
