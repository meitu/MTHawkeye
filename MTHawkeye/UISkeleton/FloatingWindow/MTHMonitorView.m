//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 02/12/2017
// Created by: EuanC
//


#import "MTHMonitorView.h"
#import "MTHMonitorViewConfiguration.h"

@interface MTHMonitorView ()

@property (nonatomic, assign) CGPoint beginPoint;
@property (nonatomic, assign) CGPoint currentPosition;

@end


@implementation MTHMonitorView

- (void)dealloc {
    [self uninstallMemoryPressureEventTrace];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];

        CGRect bounds = CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame));
        _tableView = [[UITableView alloc] initWithFrame:bounds style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.showsHorizontalScrollIndicator = NO;
        _tableView.showsVerticalScrollIndicator = NO;
        _tableView.bounces = NO;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.userInteractionEnabled = NO;

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
        if (@available(iOS 11.0, *)) {
            [_tableView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
        }
#endif

        [self addSubview:_tableView];

        [self installMemoryPressureEventTrace];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _tableView.frame = self.bounds;
}

static dispatch_source_t memoryPressureEventSource = NULL;

- (void)uninstallMemoryPressureEventTrace {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_source_cancel(memoryPressureEventSource);
        memoryPressureEventSource = NULL;
    });
}

- (void)installMemoryPressureEventTrace {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        unsigned long memoryStatusFlags = DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL;
        memoryPressureEventSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, memoryStatusFlags, dispatch_get_main_queue());
        dispatch_source_set_event_handler(memoryPressureEventSource, ^{
            unsigned long status = dispatch_source_get_data(memoryPressureEventSource);
            switch (status) {
                // VM pressure events.
                case DISPATCH_MEMORYPRESSURE_NORMAL:
                case DISPATCH_MEMORYPRESSURE_WARN:
                case DISPATCH_MEMORYPRESSURE_CRITICAL:
                default:
                    // :( tricks for create TableViewCell by ourselves, after receive vm pressure need reloadData or the tableview will be empty.
                    if ([[weakSelf.tableView subviews] count] != [weakSelf.tableView.dataSource tableView:weakSelf.tableView numberOfRowsInSection:0]) {
                        [weakSelf.tableView reloadData];
                    }
                    break;
            }
        });
        dispatch_resume(memoryPressureEventSource);
    });
}

// MARK: - touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    UITouch *touch = [touches anyObject];
    self.beginPoint = [touch locationInView:self];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];

    UIView *superView = self.superview;
    if (!superView) {
        return;
    }

    UITouch *touch = [touches anyObject];

    self.currentPosition = [touch locationInView:self];
    CGPoint targetCenter = self.center;
    CGFloat offsetX = self.currentPosition.x - self.beginPoint.x;
    CGFloat offsetY = self.currentPosition.y - self.beginPoint.y;

    if (fabs(offsetX) < 0.1 && fabs(offsetY) < 0.1) {
        return;
    }

    if (self.center.x > (superView.frame.size.width - self.frame.size.width / 2)) {
        targetCenter.x = superView.frame.size.width - self.frame.size.width / 2;
    } else if (self.center.x < self.frame.size.width / 2) {
        targetCenter.x = self.frame.size.width / 2;
    } else {
        targetCenter.x = self.center.x + offsetX;
    }

    if (self.center.y > (superView.frame.size.height - self.frame.size.height / 2)) {
        targetCenter.y = superView.frame.size.height - self.frame.size.height / 2;
    } else if (self.center.y < self.frame.size.height / 2) {
        targetCenter.y = self.frame.size.height / 2;
    } else {
        targetCenter.y = self.center.y + offsetY;
    }

    self.center = targetCenter;
    self.beginPoint = [touch locationInView:self];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    [self attachToEdgeAndSavePosition];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];

    [self attachToEdgeAndSavePosition];
}

- (void)attachToEdgeAndSavePosition {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (!self.superview) {
        return;
    }

    CGFloat safeAreaLeft = 0.f;
    CGFloat safeAreaRight = 0.f;

    CGFloat originY = self.center.y - self.frame.size.height / 2.f;
    CGFloat safeOriginY = originY;

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
        if (self.superview) {
            safeAreaLeft = self.superview.safeAreaInsets.left;
            safeAreaRight = self.superview.safeAreaInsets.right;
            safeOriginY = self.superview.safeAreaInsets.top;
        } else {
            safeAreaLeft = self.safeAreaInsets.left;
            safeAreaRight = self.safeAreaInsets.right;
            safeOriginY = self.safeAreaInsets.top;
        }
    }
#endif
    safeOriginY = safeOriginY <= originY ? originY : safeOriginY;

    CGRect rect;
    if (self.center.x >= screenBounds.size.width / 2) {
        rect = CGRectMake(screenBounds.size.width - self.frame.size.width - safeAreaRight,
            safeOriginY,
            self.frame.size.width,
            self.frame.size.height);
    } else {
        rect = CGRectMake(0 + safeAreaLeft,
            safeOriginY,
            self.frame.size.width,
            self.frame.size.height);
    }

    [UIView beginAnimations:@"move" context:nil];
    [UIView setAnimationDuration:0.2];
    [UIView setAnimationDelegate:self];
    self.frame = rect;
    [UIView commitAnimations];

    MTHMonitorViewConfiguration.monitorInitPosition = rect.origin;
}

@end
