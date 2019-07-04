//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 18/07/2017
// Created by: EuanC
//


#import "MTHNetworkWaterfallViewCell.h"
#import <MTHawkeye/MTHUISkeletonUtility.h>


static const float kTaskMetricsViewHeight = 12.f;
static const float kTaskMetricsLayerHeightS = 2.f;
static const float kTaskMetricsLayerHeightM = 6.f;
static const float kTaskMetricsLayerHeightL = 12.f;


@interface MTHNetworkWaterfallViewCell ()

// with NSURLSessionTaskMatrics
@property (nonatomic, strong) UIView *urlSessionTaskMetricsView;
@property (nonatomic, strong) CALayer *taskIntervalLayer;
@property (nonatomic, strong) CALayer *dnsLayer;
@property (nonatomic, strong) CALayer *connectionLayer;
@property (nonatomic, strong) CALayer *secureConnectionLayer;
@property (nonatomic, strong) CALayer *requestLayer;
@property (nonatomic, strong) CALayer *ttfbLayer;
@property (nonatomic, strong) CALayer *responseLayer;


// without NSURLSessionTaskMatrics
@property (nonatomic, strong) UIView *roughMetricsView;


@property (nonatomic, strong) UILabel *taskIntervalLabel;
@property (nonatomic, strong) UILabel *indexLabel;

@property (nonatomic, assign) CGFloat metricsViewWidth;
@property (nonatomic, assign) CGFloat metricsViewHeight;

@end


@implementation MTHNetworkWaterfallViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self addSubview:self.urlSessionTaskMetricsView];

        [self addSubview:self.roughMetricsView];

        for (UIView *subview in self.subviews) {
            subview.hidden = YES;
        }

        [self addSubview:self.taskIntervalLabel];
        [self addSubview:self.indexLabel];
    }
    return self;
}

- (void)prepareForReuse {
    self.backgroundColor = [UIColor whiteColor];
}


- (void)showURLSessionTaskMatricsViewWithViewModel:(MTHNetworkWaterfallViewCellModel *)viewModel {
    self.roughMetricsView.hidden = YES;
    self.urlSessionTaskMetricsView.hidden = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

    MTHURLSessionTaskMetrics *metrics = self.viewModel.transaction.taskMetrics;
    MTHURLSessionTaskTransactionMetrics *transMetrics = metrics.transactionMetrics.lastObject;
    CGFloat taskStartAt = [metrics.taskInterval.startDate timeIntervalSince1970];
    CGFloat taskDuration = metrics.taskInterval.duration;

    const CGFloat smallLayerPosY = (self.metricsViewHeight - kTaskMetricsLayerHeightS) / 2.f;
    const CGFloat middleLayerPosY = (self.metricsViewHeight - kTaskMetricsLayerHeightM) / 2.f;
    const CGFloat largeLayerPosY = (self.metricsViewHeight - kTaskMetricsLayerHeightL) / 2.f;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat taskMetricsDuration = metrics.taskInterval.duration;
    self.taskIntervalLayer.hidden = taskMetricsDuration <= 0.001f;
    if (taskMetricsDuration > 0.001f) {
        CGFloat left = ceil(([metrics.taskInterval.startDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat width = ceil(self.urlSessionTaskMetricsView.bounds.size.width);
        self.taskIntervalLayer.frame = CGRectMake(left, smallLayerPosY, width, kTaskMetricsLayerHeightS);
    }

    CGFloat dnsDuration = [transMetrics.domainLookupEndDate timeIntervalSinceDate:transMetrics.domainLookupStartDate];
    self.dnsLayer.hidden = dnsDuration <= 0.001f;
    if (dnsDuration > 0.001f) {
        CGFloat dnsLeft = ceil(([transMetrics.domainLookupStartDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat dnsWidth = ceil(dnsDuration / taskDuration * self.metricsViewWidth);
        self.dnsLayer.frame = CGRectMake(dnsLeft, middleLayerPosY, dnsWidth, kTaskMetricsLayerHeightM);
    }

    CGFloat connDuration = [transMetrics.connectEndDate timeIntervalSinceDate:transMetrics.connectStartDate];
    self.connectionLayer.hidden = connDuration <= 0.001f;
    if (connDuration > 0.001f) {
        CGFloat connLeft = ceil(([transMetrics.connectStartDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat connWidth = ceil(connDuration / taskDuration * self.metricsViewWidth);
        self.connectionLayer.frame = CGRectMake(connLeft, middleLayerPosY, connWidth, kTaskMetricsLayerHeightM);
    }

    CGFloat secureConnDuration = [transMetrics.secureConnectionEndDate timeIntervalSinceDate:transMetrics.secureConnectionStartDate];
    self.secureConnectionLayer.hidden = secureConnDuration <= 0.001f;
    if (secureConnDuration > 0.001f) {
        CGFloat sConnLeft = ceil(([transMetrics.secureConnectionStartDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat sConnWidth = ceil(secureConnDuration / taskDuration * self.metricsViewWidth);
        self.secureConnectionLayer.frame = CGRectMake(sConnLeft, smallLayerPosY, sConnWidth, kTaskMetricsLayerHeightS);
    }

    CGFloat requestDuration = [transMetrics.requestEndDate timeIntervalSinceDate:transMetrics.requestStartDate];
    self.requestLayer.hidden = requestDuration <= 0.001f;
    if (requestDuration > 0.001f) {
        CGFloat reqLeft = ceil(([transMetrics.requestStartDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat reqWidth = ceil(requestDuration / taskDuration * self.metricsViewWidth);
        self.requestLayer.frame = CGRectMake(reqLeft, largeLayerPosY, reqWidth, kTaskMetricsLayerHeightL);
    }

    CGFloat responseDuration = [transMetrics.responseEndDate timeIntervalSinceDate:transMetrics.responseStartDate];
    self.responseLayer.hidden = responseDuration <= 0.001f;
    if (responseDuration > 0.001f) {
        CGFloat repLeft = ceil(([transMetrics.responseStartDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
        CGFloat repWidth = ceil(responseDuration / taskDuration * self.metricsViewWidth);
        self.responseLayer.frame = CGRectMake(repLeft, largeLayerPosY, repWidth, kTaskMetricsLayerHeightL);
    }

    CGFloat ttfbDuration = [transMetrics.responseStartDate timeIntervalSinceDate:transMetrics.requestEndDate];
    self.ttfbLayer.hidden = ttfbDuration <= 0.001f;
    if (ttfbDuration > 0.001f) {
        CGFloat ttfbLeft;
        CGFloat ttfbWidth;
        if (requestDuration > 0.001f && responseDuration > 0.001f) {
            ttfbLeft = self.requestLayer.frame.origin.x + self.requestLayer.frame.size.width;
            ttfbWidth = self.responseLayer.frame.origin.x - ttfbLeft;
        } else {
            ttfbLeft = ceil(([transMetrics.requestEndDate timeIntervalSince1970] - taskStartAt) / taskDuration * self.metricsViewWidth);
            ttfbWidth = ceil([transMetrics.responseStartDate timeIntervalSinceDate:transMetrics.requestEndDate] / taskDuration * self.metricsViewWidth);
        }
        self.ttfbLayer.frame = CGRectMake(ttfbLeft, largeLayerPosY, ttfbWidth, kTaskMetricsLayerHeightL);
    }

    if (viewModel.transaction == viewModel.focusedTransaction) {
        self.backgroundColor = [UIColor colorWithRed:0.737 green:0.847 blue:0.976 alpha:.2f];
    }

    [CATransaction commit];

#pragma clang diagnostic pop
}

- (void)showRoughMatricsViewWithViewModel:(MTHNetworkWaterfallViewCellModel *)viewModel {
    self.urlSessionTaskMetricsView.hidden = YES;
    self.roughMetricsView.hidden = NO;

    if (viewModel.transaction == viewModel.focusedTransaction) {
        self.roughMetricsView.backgroundColor = [UIColor colorWithRed:0.624 green:0.78 blue:0.969 alpha:1];
    } else {
        self.roughMetricsView.backgroundColor = [UIColor colorWithWhite:0.847 alpha:1];
    }
}

+ (CGFloat)marginLeft {
    return 30.f;
}

+ (CGFloat)marginRight {
    return 20.f;
}

- (CGFloat)availableContentViewWidth {
    const CGFloat availableViewWidth = self.bounds.size.width - [[self class] marginLeft] - [[self class] marginRight];
    return availableViewWidth;
}

- (void)setViewModel:(MTHNetworkWaterfallViewCellModel *)viewModel {
    _viewModel = viewModel;

    CGPoint center;
    CGFloat intervalToLeft = [viewModel.transaction.startTime timeIntervalSince1970] - viewModel.timelineStartAt;
    CGFloat left = [[self class] marginLeft];
    self.metricsViewWidth = 0.f;
    if (viewModel.timelineDuration > 0.001f) {
        left += ceil(intervalToLeft / viewModel.timelineDuration * [self availableContentViewWidth]);
        self.metricsViewWidth = ceil(viewModel.transaction.duration / viewModel.timelineDuration * [self availableContentViewWidth]);
    }
    if (self.metricsViewWidth <= 1.f) {
        self.metricsViewWidth = 2.f;
    }
    self.metricsViewHeight = kTaskMetricsViewHeight;

    CGRect metricsViewFrame = CGRectMake(left, ceil((self.bounds.size.height - self.metricsViewHeight) / 2), self.metricsViewWidth, self.metricsViewHeight);

    if ([viewModel.transaction useURLSessionTaskMetrics]) {
        self.urlSessionTaskMetricsView.frame = metricsViewFrame;
        center = self.urlSessionTaskMetricsView.center;

        [self showURLSessionTaskMatricsViewWithViewModel:viewModel];

    } else {
        self.roughMetricsView.frame = metricsViewFrame;
        center = self.roughMetricsView.center;
        [self showRoughMatricsViewWithViewModel:viewModel];
    }

    self.taskIntervalLabel.textColor = [UIColor colorWithWhite:0.0667 alpha:1];

    NSString *durationString = [MTHUISkeletonUtility stringFromRequestDuration:viewModel.transaction.duration];
    if (viewModel.transaction.transactionState == MTHNetworkTransactionStateFinished) {
        self.taskIntervalLabel.text = [NSString stringWithFormat:@"%@·%@", durationString, [self netQualityTextForTransaction:viewModel.transaction]];
    } else if (viewModel.transaction.transactionState == MTHNetworkTransactionStateFailed) {
        NSString *statusCodeString = [MTHUISkeletonUtility statusCodeStringFromURLResponse:viewModel.transaction.response];
        self.taskIntervalLabel.text = [NSString stringWithFormat:@"%@ %@ %@", durationString, statusCodeString ?: @"", [self netQualityTextForTransaction:viewModel.transaction]];

        self.taskIntervalLabel.textColor = [UIColor colorWithRed:0.816 green:0.00392 blue:0.106 alpha:1];
    } else {
        self.taskIntervalLabel.text = [NSString stringWithFormat:@"⏳·%@", [self netQualityTextForTransaction:viewModel.transaction]];
    }

    [self.taskIntervalLabel sizeToFit];
    CGFloat mainLeft = metricsViewFrame.origin.x;
    CGFloat mainRight = metricsViewFrame.origin.x + metricsViewFrame.size.width;
    CGFloat labelWidth = self.taskIntervalLabel.bounds.size.width;
    CGFloat centerX = 0.f;
    if (self.bounds.size.width - mainRight >= labelWidth + 5.f) {
        centerX = mainRight + labelWidth / 2.f + 5.f;
        if (centerX < 0.f) {
            // 如果请求还返回，且时间跨度较大，可能绘制到屏幕左边之外
            centerX = labelWidth + [[self class] marginLeft];
        }
    } else if (mainLeft >= (labelWidth + 5.f + 20.f)) {
        centerX = mainLeft - labelWidth / 2.f - 5.f;
    } else if (self.bounds.size.width - mainRight < labelWidth + 5.f) {
        // 超出整体长度
        centerX = self.bounds.size.width - labelWidth;
    } else {
        centerX = mainRight - labelWidth / 2.f - 5.f;
    }

    self.taskIntervalLabel.center = CGPointMake(centerX, center.y);

    self.indexLabel.text = [NSString stringWithFormat:@"%@", @(viewModel.transaction.requestIndex)];
    [self.indexLabel sizeToFit];
    CGSize indexLabelSize = self.indexLabel.bounds.size;
    self.indexLabel.frame = CGRectMake(0, self.taskIntervalLabel.frame.origin.y, indexLabelSize.width, self.taskIntervalLabel.frame.size.height);
}

- (NSString *)netQualityTextForTransaction:(MTHNetworkTransaction *)transaction {
    if (transaction.transactionState == MTHNetworkTransactionStateFinished || transaction.transactionState == MTHNetworkTransactionStateFailed) {
        if (transaction.netQualityAtStart != transaction.netQualityAtEnd && transaction.netQualityAtStart != MTHawkeyeNetworkConnectionQualityUnknown) {
            return [NSString stringWithFormat:@"%@-%@", [self netQualityTextForConnectionQuality:transaction.netQualityAtStart], [self netQualityTextForConnectionQuality:transaction.netQualityAtEnd]];
        } else {
            return [self netQualityTextForConnectionQuality:transaction.netQualityAtEnd];
        }
    } else {
        return [self netQualityTextForConnectionQuality:transaction.netQualityAtStart];
    }
}

- (NSString *)netQualityTextForConnectionQuality:(MTHawkeyeNetworkConnectionQuality)connQuality {
    switch (connQuality) {
        case MTHawkeyeNetworkConnectionQualityUnknown:
            return @"u";
        case MTHawkeyeNetworkConnectionQualityPoor:
            return @"p";
        case MTHawkeyeNetworkConnectionQualityModerate:
            return @"m";
        case MTHawkeyeNetworkConnectionQualityGood:
            return @"g";
        case MTHawkeyeNetworkConnectionQualityExcellent:
            return @"e";
    }
}

// MARK: - getter
- (UILabel *)taskIntervalLabel {
    if (_taskIntervalLabel == nil) {
        _taskIntervalLabel = [[UILabel alloc] init];
        _taskIntervalLabel.textColor = [UIColor colorWithWhite:0.0118 alpha:1];
        _taskIntervalLabel.font = [UIFont systemFontOfSize:10.f];
    }
    return _taskIntervalLabel;
}

- (UILabel *)indexLabel {
    if (_indexLabel == nil) {
        _indexLabel = [[UILabel alloc] init];
        _indexLabel.textColor = [UIColor colorWithWhite:0.0118 alpha:1];
        _indexLabel.font = [UIFont systemFontOfSize:10.f];
    }
    return _indexLabel;
}

- (UIView *)roughMetricsView {
    if (_roughMetricsView == nil) {
        _roughMetricsView = [[UIView alloc] init];
        _roughMetricsView.backgroundColor = [UIColor colorWithWhite:0.847 alpha:1];
    }
    return _roughMetricsView;
}

- (UIView *)urlSessionTaskMetricsView {
    if (_urlSessionTaskMetricsView == nil) {
        _urlSessionTaskMetricsView = [[UIView alloc] init];
        _urlSessionTaskMetricsView.bounds = CGRectMake(0, 0, 0.f, kTaskMetricsViewHeight);
        _urlSessionTaskMetricsView.backgroundColor = self.backgroundColor;

        [_urlSessionTaskMetricsView.layer addSublayer:self.taskIntervalLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.dnsLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.connectionLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.secureConnectionLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.requestLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.ttfbLayer];
        [_urlSessionTaskMetricsView.layer addSublayer:self.responseLayer];
    }
    return _urlSessionTaskMetricsView;
}

- (CALayer *)taskIntervalLayer {
    if (_taskIntervalLayer == nil) {
        _taskIntervalLayer = [[CALayer alloc] init];
        _taskIntervalLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightS) / 2, 0.f, kTaskMetricsLayerHeightS);
        _taskIntervalLayer.backgroundColor = [UIColor colorWithWhite:0.733 alpha:1].CGColor;
    }
    return _taskIntervalLayer;
}

- (CALayer *)dnsLayer {
    if (_dnsLayer == nil) {
        _dnsLayer = [[CALayer alloc] init];
        _dnsLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightM) / 2, 0.f, kTaskMetricsLayerHeightM);
        _dnsLayer.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1].CGColor;
    }
    return _dnsLayer;
}

- (CALayer *)connectionLayer {
    if (_connectionLayer == nil) {
        _connectionLayer = [[CALayer alloc] init];
        _connectionLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightM) / 2, 0.f, kTaskMetricsLayerHeightM);
        _connectionLayer.backgroundColor = [UIColor colorWithWhite:0.439 alpha:1].CGColor;
    }
    return _connectionLayer;
}

- (CALayer *)secureConnectionLayer {
    if (_secureConnectionLayer == nil) {
        _secureConnectionLayer = [[CALayer alloc] init];
        _secureConnectionLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightS) / 2, 0.f, kTaskMetricsLayerHeightS);
        _secureConnectionLayer.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1].CGColor;
    }
    return _secureConnectionLayer;
}

- (CALayer *)requestLayer {
    if (_requestLayer == nil) {
        _requestLayer = [[CALayer alloc] init];
        _requestLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightL) / 2, 0.f, kTaskMetricsLayerHeightL);
        _requestLayer.backgroundColor = [UIColor colorWithWhite:0.439 alpha:1].CGColor;
    }
    return _requestLayer;
}

- (CALayer *)ttfbLayer {
    if (_ttfbLayer == nil) {
        _ttfbLayer = [[CALayer alloc] init];
        _ttfbLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightL) / 2, 0.f, kTaskMetricsLayerHeightL);
        _ttfbLayer.backgroundColor = [UIColor colorWithWhite:0.565 alpha:1].CGColor;
    }
    return _ttfbLayer;
}

- (CALayer *)responseLayer {
    if (_responseLayer == nil) {
        _responseLayer = [[CALayer alloc] init];
        _responseLayer.frame = CGRectMake(0, (kTaskMetricsViewHeight - kTaskMetricsLayerHeightL) / 2, 0.f, kTaskMetricsLayerHeightL);
        _responseLayer.backgroundColor = [UIColor colorWithWhite:0.439 alpha:1].CGColor;
    }
    return _responseLayer;
}

@end
