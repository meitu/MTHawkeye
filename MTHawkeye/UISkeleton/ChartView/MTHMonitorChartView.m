//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 04/07/2017
// Created by: EuanC
//


#import "MTHMonitorChartView.h"
#import "MTHSimpleLineGraphView.h"


@interface MTHMonitorChartView () <MTHSimpleLineGraphDataSource, MTHSimpleLineGraphDelegate>

@property (strong, nonatomic) MTHSimpleLineGraphView *myGraph;
@property (strong, nonatomic) UILabel *unitLabel;

@end


@implementation MTHMonitorChartView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupGraphView];
    }
    return self;
}

- (void)setupGraphView {
    self.myGraph = [[MTHSimpleLineGraphView alloc] initWithFrame:self.bounds];
    self.myGraph.delegate = self;
    self.myGraph.dataSource = self;

    self.myGraph.colorLine = [UIColor lightGrayColor];
    self.myGraph.colorTop = [UIColor whiteColor];
    self.myGraph.colorBottom = [UIColor lightGrayColor];
    self.myGraph.backgroundColor = [UIColor whiteColor];
    self.myGraph.colorBackgroundXaxis = [UIColor whiteColor];
    self.myGraph.colorBackgroundYaxis = [UIColor whiteColor];

    // Enable and disable various graph properties and axis displays
    self.myGraph.animationGraphStyle = MTHLineAnimationNone;
    self.myGraph.enableTouchReport = YES;
    self.myGraph.enablePopUpReport = YES;
    self.myGraph.enableYAxisLabel = YES;
    self.myGraph.enableXAxisLabel = YES;
    self.myGraph.autoScaleYAxis = YES;
    self.myGraph.alwaysDisplayDots = NO;
    self.myGraph.enableReferenceXAxisLines = NO;
    self.myGraph.enableReferenceYAxisLines = NO;
    self.myGraph.enableReferenceAxisFrame = NO;

    self.myGraph.formatStringForValues = @"%.1f";
    self.myGraph.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:self.myGraph];

    CGRect unitLableFrame = CGRectMake(0, self.bounds.size.height - 30, 30, 15);
    self.unitLabel = [[UILabel alloc] initWithFrame:unitLableFrame];
    self.unitLabel.text = self.unitLabelTitle;
    self.unitLabel.font = [UIFont systemFontOfSize:10];
    self.unitLabel.textColor = [UIColor lightGrayColor];
    self.unitLabel.textAlignment = NSTextAlignmentRight;
    [self addSubview:self.unitLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect safeArea = self.bounds;
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11, *)) {
        safeArea = UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets);
    }
#endif
    self.myGraph.frame = safeArea;
    self.unitLabel.frame = CGRectMake(CGRectGetMinX(safeArea), CGRectGetHeight(self.bounds) - 30, 30, 15);
}

- (void)reloadData {
    @autoreleasepool {
        [self.myGraph reloadGraph];
    }
}

- (void)setUnitLabelTitle:(NSString *)unitLabelTitle {
    _unitLabelTitle = unitLabelTitle;
    if (self.unitLabel) {
        self.unitLabel.text = unitLabelTitle;
    }
}


// MARK: - MTHSimpleLineGraphDataSource

- (NSInteger)numberOfPointsInLineGraph:(MTHSimpleLineGraphView *)graph {
    return [self.delegate numberOfPointsInChartView:self];
}

- (CGFloat)lineGraph:(MTHSimpleLineGraphView *)graph valueForPointAtIndex:(NSInteger)index {
    return [self.delegate chartView:self valueForPointAtIndex:index];
}

// MARK: - MTHSimpleLineGraphDelegate

- (void)lineGraph:(MTHSimpleLineGraphView *)graph didTouchGraphWithClosestIndex:(NSInteger)index {
}

- (void)lineGraph:(MTHSimpleLineGraphView *)graph didReleaseTouchFromGraphWithClosestIndex:(CGFloat)index {
}

- (NSInteger)baseIndexForXAxisOnLineGraph:(MTHSimpleLineGraphView *)graph {
    return 0;
}

- (NSInteger)incrementIndexForXAxisOnLineGraph:(MTHSimpleLineGraphView *)graph {
    return 2;
}

- (BOOL)rangeSelectEnableForLineGraph:(MTHSimpleLineGraphView *)graph {
    if ([self delegateValidForSEL:@selector(rangeSelectEnableForChartView:)]) {
        return [self.delegate rangeSelectEnableForChartView:self];
    }
    return NO;
}

- (void)lineGraph:(MTHSimpleLineGraphView *)graph didSelectedWithIndexRange:(NSRange)indexRange {
    if ([self delegateValidForSEL:@selector(chartView:didSelectedWithIndexRange:)]) {
        return [self.delegate chartView:self didSelectedWithIndexRange:indexRange];
    }
}

- (BOOL)delegateValidForSEL:(SEL)sel {
    if ([self.delegate respondsToSelector:sel] && self.delegate) {
        return YES;
    }
    return NO;
}

@end
