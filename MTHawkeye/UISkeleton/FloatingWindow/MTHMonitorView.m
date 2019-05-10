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
        if (memoryPressureEventSource) {
            dispatch_source_cancel(memoryPressureEventSource);
            memoryPressureEventSource = NULL;
        }
    });
}

- (void)installMemoryPressureEventTrace {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        unsigned long memoryStatusFlags = DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL;
        memoryPressureEventSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, memoryStatusFlags, dispatch_get_main_queue());
        dispatch_source_set_event_handler(memoryPressureEventSource, ^{
            if (weakSelf.window == nil || weakSelf.window.hidden || weakSelf.hidden)
                return;

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

    CGPoint currentPosition = [touch locationInView:self];
    CGPoint targetCenter = self.center;
    CGFloat offsetX = currentPosition.x - self.beginPoint.x;
    CGFloat offsetY = currentPosition.y - self.beginPoint.y;

    if (fabs(offsetX) < 1 && fabs(offsetY) < 1) {
        return;
    }
    targetCenter.x = ceil(self.center.x + offsetX);
    targetCenter.y = ceil(self.center.y + offsetY);

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

- (CGRect)placeViewSafeArea {
    CGRect safeArea = self.window.bounds;
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11, *)) {
        safeArea = UIEdgeInsetsInsetRect(self.window.bounds, self.window.safeAreaInsets);
    }
#endif
    return safeArea;
}

- (void)attachToEdgeAndSavePosition {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (!self.window) {
        return;
    }

    CGRect safeArea = [self placeViewSafeArea];
    CGFloat minX = CGRectGetMinX(safeArea);
    CGFloat maxX = CGRectGetMaxX(safeArea);
    CGFloat minY = CGRectGetMinY(safeArea);
    CGFloat maxY = CGRectGetMaxY(safeArea);

    CGFloat y = CGRectGetMinY(self.frame);
    if (y < minY)
        y = minY;
    if (y > (maxY - CGRectGetHeight(self.frame)))
        y = maxY - CGRectGetHeight(self.frame);

    UIViewAutoresizing autoresizingMask;
    CGRect rectToAttach;
    if (self.center.x >= CGRectGetWidth(screenBounds) / 2) {
        rectToAttach = CGRectMake(maxX - CGRectGetWidth(self.frame), y, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
        autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
    } else {
        rectToAttach = CGRectMake(minX, y, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
        autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    }

    [UIView animateWithDuration:.2f
        animations:^{
            self.frame = rectToAttach;
        }
        completion:^(BOOL finished) {
            if (self.autoresizingMask != autoresizingMask)
                self.autoresizingMask = autoresizingMask;

            MTHMonitorViewConfiguration.monitorInitPosition = rectToAttach.origin;
        }];
}

@end
