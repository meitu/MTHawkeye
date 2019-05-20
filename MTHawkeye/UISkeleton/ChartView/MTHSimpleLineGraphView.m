//
//  MTHSimpleLineGraphView.m
//  SimpleLineGraph
//
//  Created by Bobo on 12/27/13. Updated by Sam Spencer on 1/11/14.
//  Copyright (c) 2013 Boris Emorine. All rights reserved.
//  Copyright (c) 2014 Sam Spencer.
//

#import "MTHSimpleLineGraphView.h"

const CGFloat MTHNullGraphValue = CGFLOAT_MAX;
static const NSInteger kTagBaseForLineController = 889911;

#define kTouchLineColor [UIColor colorWithRed:1 green:0.82 blue:0.522 alpha:1]

#if !__has_feature(objc_arc)
// Add the -fobjc-arc flag to enable ARC for only these files, as described in the ARC documentation: http://clang.llvm.org/docs/AutomaticReferenceCounting.html
#error MTHSimpleLineGraph is built with Objective-C ARC. You must enable ARC for these files.
#endif

#define DEFAULT_FONT_NAME @"HelveticaNeue-Light"


typedef NS_ENUM(NSInteger, MTHInternalTags) {
    DotFirstTag100 = 100,
    DotLastTag1000 = 1000,
    LabelYAxisTag2000 = 2000,
    BackgroundYAxisTag2100 = 2100,
    BackgroundXAxisTag2200 = 2200,
    PermanentPopUpViewTag3100 = 3100,
    PanViewTag4000 = 4000,
};

@interface MTHTouchLineView : UIView

@property (nonatomic, strong) UILabel *numLabel;
- (instancetype)initWithFrame:(CGRect)frame labelTopOffset:(CGFloat)topOffset;
- (void)setValueForNumberLabel:(NSNumber *)value;
- (void)reloadNumLabelFrameWithMaxWidth:(CGFloat)maxWidth;

@end

@interface MTHSimpleLineGraphView () {
    /// The number of Points in the Graph
    NSInteger numberOfPoints;

    /// The closest point to the touch point
    CGFloat currentlyCloser;

    /// All of the X-Axis Values
    NSMutableArray *xAxisValues;

    /// All of the X-Axis Label Points
    NSMutableArray *xAxisLabelPoints;

    /// All of the X-Axis Label Points
    CGFloat xAxisHorizontalFringeNegationValue;

    /// All of the Y-Axis Label Points
    NSMutableArray *yAxisLabelPoints;

    /// All of the Y-Axis Values
    NSMutableArray *yAxisValues;

    /// All of the Data Points
    NSMutableArray *dataPoints;

    /// All of the X-Axis Labels
    NSMutableArray *xAxisLabels;
}

/// The vertical line which appears when the user drags across the graph
@property (strong, nonatomic) UIView *touchInputLine;

// lwj:
@property (strong, nonatomic) MTHTouchLineView *leftTouchLine;
@property (strong, nonatomic) MTHTouchLineView *rightTouchLine;
@property (nonatomic, assign) NSInteger leftSelectedIdx;
@property (nonatomic, assign) NSInteger rightSelectedIdx;
@property (nonatomic, assign) BOOL isGraphSelected;
@property (nonatomic, strong) CAShapeLayer *selectedShapeLayer;

/// View for picking up pan gesture
@property (strong, nonatomic, readwrite) UIView *panView;

/// Label to display when there is no data
@property (strong, nonatomic) UILabel *noDataLabel;

/// The gesture recognizer picking up the pan in the graph view
@property (strong, nonatomic) UIPanGestureRecognizer *panGesture;

/// This gesture recognizer picks up the initial touch on the graph view
@property (nonatomic) UILongPressGestureRecognizer *longPressGesture;

/// The label displayed when enablePopUpReport is set to YES
@property (strong, nonatomic) UILabel *popUpLabel;

/// The view used for the background of the popup label
@property (strong, nonatomic) UIView *popUpView;

/// The X position (center) of the view for the popup label
@property (nonatomic) CGFloat xCenterLabel;

/// The Y position (center) of the view for the popup label
@property (nonatomic) CGFloat yCenterLabel;

/// The Y offset necessary to compensate the labels on the X-Axis
@property (nonatomic) CGFloat XAxisLabelYOffset;

/// The X offset necessary to compensate the labels on the Y-Axis. Will take the value of the bigger label on the Y-Axis
@property (nonatomic) CGFloat YAxisLabelXOffset;

/// The biggest value out of all of the data points
@property (nonatomic) CGFloat maxValue;

/// The smallest value out of all of the data points
@property (nonatomic) CGFloat minValue;

/// Determines the biggest Y-axis value from all the points
- (CGFloat)maxValue;

/// Determines the smallest Y-axis value from all the points
- (CGFloat)minValue;

// Tracks whether the popUpView is custom or default
@property (nonatomic) BOOL usingCustomPopupView;

// Stores the current view size to detect whether a redraw is needed in layoutSubviews
@property (nonatomic) CGSize currentViewSize;

// Stores the background X Axis view
@property (nonatomic) UIView *backgroundXAxis;

@property (nonatomic, strong) MTHLine *line;

// Draw Y Axis view
@property (nonatomic, strong) UIView *backgroundYaxis;
@property (nonatomic, strong) UILabel *minYAxisLabel;
@property (nonatomic, strong) UILabel *maxYAxisLabel;
@property (nonatomic, strong) UILabel *aveYAxisLabel;

@property (nonatomic, assign) BOOL haveInitSelctedIndex;
@end

@implementation MTHSimpleLineGraphView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self commonInit];
    return self;
}

- (void)commonInit {
    // Do any initialization that's common to both -initWithFrame: and -initWithCoder: in this method

    // Set the X Axis label font
    _labelFont = [UIFont fontWithName:DEFAULT_FONT_NAME size:13];

    // Set Animation Values
    _animationGraphEntranceTime = 1.5;

    // Set Color Values
    _colorXaxisLabel = [UIColor blackColor];
    _colorYaxisLabel = [UIColor blackColor];
    _colorTop = [UIColor colorWithRed:0 green:122.0 / 255.0 blue:255 / 255 alpha:1];
    _colorLine = [UIColor colorWithRed:255.0 / 255.0 green:255.0 / 255.0 blue:255.0 / 255.0 alpha:1];
    _colorBottom = [UIColor colorWithRed:0 green:122.0 / 255.0 blue:255 / 255 alpha:1];
    _colorPoint = [UIColor colorWithWhite:1.0 alpha:0.7];
    _colorTouchInputLine = [UIColor grayColor];
    _colorBackgroundPopUplabel = [UIColor whiteColor];
    _alphaTouchInputLine = 0.2;
    _widthTouchInputLine = 1.0;
    _colorBackgroundXaxis = nil;
    _alphaBackgroundXaxis = 1.0;
    _colorBackgroundYaxis = nil;
    _alphaBackgroundYaxis = 1.0;
    _displayDotsWhileAnimating = YES;

    // Set Alpha Values
    _alphaTop = 1.0;
    _alphaBottom = 1.0;
    _alphaLine = 1.0;

    // Set Size Values
    _widthLine = 1.0;
    _widthReferenceLines = 1.0;
    _sizePoint = 10.0;

    // Set Default Feature Values
    _enableTouchReport = NO;
    _touchReportFingersRequired = 1;
    _enablePopUpReport = NO;
    _enableBezierCurve = NO;
    _enableXAxisLabel = YES;
    _enableYAxisLabel = NO;
    _YAxisLabelXOffset = 0;
    _autoScaleYAxis = YES;
    _alwaysDisplayDots = NO;
    _alwaysDisplayPopUpLabels = NO;
    _enableLeftReferenceAxisFrameLine = YES;
    _enableBottomReferenceAxisFrameLine = YES;
    _formatStringForValues = @"%.0f";
    _interpolateNullValues = YES;
    _displayDotsOnly = NO;

    // Initialize the various arrays
    xAxisValues = [NSMutableArray array];
    xAxisHorizontalFringeNegationValue = 0.0;
    xAxisLabelPoints = [NSMutableArray array];
    yAxisLabelPoints = [NSMutableArray array];
    dataPoints = [NSMutableArray array];
    xAxisLabels = [NSMutableArray array];
    yAxisValues = [NSMutableArray array];
}

- (void)prepareForInterfaceBuilder {
    // Set points and remove all dots that were previously on the graph
    numberOfPoints = 10;
    for (UILabel *subview in [self subviews]) {
        if ([subview isEqual:self.noDataLabel])
            [subview removeFromSuperview];
    }

    [self drawEntireGraph];
}

- (void)drawGraph {
    // Let the delegate know that the graph began layout updates
    if ([self.delegate respondsToSelector:@selector(lineGraphDidBeginLoading:)])
        [self.delegate lineGraphDidBeginLoading:self];

    // Get the number of points in the graph
    [self layoutNumberOfPoints];

    if (numberOfPoints <= 1) {
        return;
    } else {
        // Draw the graph
        [self drawEntireGraph];

        // Setup the touch report
        [self layoutTouchReport];

        [self _drawXAxis];

        // Let the delegate know that the graph finished updates
        if ([self.delegate respondsToSelector:@selector(lineGraphDidFinishLoading:)])
            [self.delegate lineGraphDidFinishLoading:self];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (CGSizeEqualToSize(self.currentViewSize, self.bounds.size)) return;
    self.currentViewSize = self.bounds.size;

    [self drawGraph];
}

- (void)layoutNumberOfPoints {
    // Get the total number of data points from the delegate
    if ([self.dataSource respondsToSelector:@selector(numberOfPointsInLineGraph:)]) {
        numberOfPoints = [self.dataSource numberOfPointsInLineGraph:self];
    } else if ([self.delegate respondsToSelector:@selector(numberOfPointsInGraph)]) {
        [self printDeprecationWarningForOldMethod:@"numberOfPointsInGraph" andReplacementMethod:@"numberOfPointsInLineGraph:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        numberOfPoints = [self.delegate numberOfPointsInGraph];
#pragma clang diagnostic pop

    } else if ([self.delegate respondsToSelector:@selector(numberOfPointsInLineGraph:)]) {
        [self printDeprecationAndUnavailableWarningForOldMethod:@"numberOfPointsInLineGraph:"];
        numberOfPoints = 0;

    } else
        numberOfPoints = 0;

    // There are no points to load
    if (numberOfPoints == 0) {
        if (self.delegate &&
            [self.delegate respondsToSelector:@selector(noDataLabelEnableForLineGraph:)] && ![self.delegate noDataLabelEnableForLineGraph:self]) return;

        NSLog(@"[MTHSimpleLineGraph] Data source contains no data. A no data label will be displayed and drawing will stop. Add data to the data source and then reload the graph.");

#if !TARGET_INTERFACE_BUILDER
        self.noDataLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.viewForBaselineLayout.frame.size.width, self.viewForBaselineLayout.frame.size.height)];
#else
        self.noDataLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.viewForBaselineLayout.frame.size.width, self.viewForBaselineLayout.frame.size.height - (self.viewForBaselineLayout.frame.size.height / 4))];
#endif

        self.noDataLabel.backgroundColor = [UIColor clearColor];
        self.noDataLabel.textAlignment = NSTextAlignmentCenter;

#if !TARGET_INTERFACE_BUILDER
        NSString *noDataText;
        if ([self.delegate respondsToSelector:@selector(noDataLabelTextForLineGraph:)]) {
            noDataText = [self.delegate noDataLabelTextForLineGraph:self];
        }
        self.noDataLabel.text = noDataText ?: NSLocalizedString(@"Empty Records", nil);
#else
        self.noDataLabel.text = @"Data is not loaded in Interface Builder";
#endif
        self.noDataLabel.font = self.noDataLabelFont ?: [UIFont fontWithName:@"HelveticaNeue-Light" size:15];
        self.noDataLabel.textColor = self.noDataLabelColor ?: self.colorLine;

        [self.viewForBaselineLayout addSubview:self.noDataLabel];

        // Let the delegate know that the graph finished layout updates
        if ([self.delegate respondsToSelector:@selector(lineGraphDidFinishLoading:)])
            [self.delegate lineGraphDidFinishLoading:self];
        return;

    } else {
        // Remove all dots that were previously on the graph
        for (UILabel *subview in [self subviews]) {
            if ([subview isEqual:self.noDataLabel])
                [subview removeFromSuperview];
        }
    }
}

- (void)layoutTouchReport {
    // If the touch report is enabled, set it up
    if (self.enableTouchReport == YES || self.enablePopUpReport == YES) {

        // Initialize the vertical gray line that appears where the user touches the graph.
        [self addPanView];
        [self addTouchInputLine];
        [self addLeftTouchLine];
        [self addRightTouchLine];

        if (self.enablePopUpReport == YES && self.alwaysDisplayPopUpLabels == NO) {
            if ([self.delegate respondsToSelector:@selector(popUpViewForLineGraph:)]) {
                self.popUpView = [self.delegate popUpViewForLineGraph:self];
                self.usingCustomPopupView = YES;
                self.popUpView.alpha = 0;
                [self addSubview:self.popUpView];
            } else {
                NSString *maxValueString = [NSString stringWithFormat:self.formatStringForValues, [self calculateMaximumPointValue].doubleValue];
                NSString *minValueString = [NSString stringWithFormat:self.formatStringForValues, [self calculateMinimumPointValue].doubleValue];

                NSString *longestString = @"";
                if (maxValueString.length > minValueString.length) {
                    longestString = maxValueString;
                } else {
                    longestString = minValueString;
                }

                NSString *prefix = @"";
                NSString *suffix = @"";
                if ([self.delegate respondsToSelector:@selector(popUpSuffixForlineGraph:)]) {
                    suffix = [self.delegate popUpSuffixForlineGraph:self];
                }
                if ([self.delegate respondsToSelector:@selector(popUpPrefixForlineGraph:)]) {
                    prefix = [self.delegate popUpPrefixForlineGraph:self];
                }

                NSString *fullString = [NSString stringWithFormat:@"%@%@%@", prefix, longestString, suffix];

                NSString *mString = [fullString stringByReplacingOccurrencesOfString:@"[0-9-]" withString:@"N" options:NSRegularExpressionSearch range:NSMakeRange(0, [longestString length])];

                if (self.popUpLabel == nil) {
                    self.popUpLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
                }
                self.popUpLabel.text = mString;
                self.popUpLabel.textAlignment = 1;
                self.popUpLabel.numberOfLines = 1;
                self.popUpLabel.font = self.labelFont;
                self.popUpLabel.backgroundColor = [UIColor clearColor];
                [self.popUpLabel sizeToFit];
                self.popUpLabel.alpha = 0;
                if (self.popUpView == nil) {
                    self.popUpView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.popUpLabel.frame.size.width + 10, self.popUpLabel.frame.size.height + 2)];
                }
                self.popUpView.backgroundColor = self.colorBackgroundPopUplabel;
                self.popUpView.alpha = 0;
                self.popUpView.layer.cornerRadius = 3;
                [self addSubview:self.popUpView];
                [self addSubview:self.popUpLabel];
            }
        }

        [self.viewForBaselineLayout bringSubviewToFront:_panView];
    }
}

#pragma mark - Drawing

- (void)didFinishDrawingIncludingYAxis:(BOOL)yAxisFinishedDrawing {
    if (self.enableYAxisLabel == NO) {
        // Let the delegate know that the graph finished rendering
        if ([self.delegate respondsToSelector:@selector(lineGraphDidFinishDrawing:)])
            [self.delegate lineGraphDidFinishDrawing:self];
        return;
    } else {
        if (yAxisFinishedDrawing == YES) {
            // Let the delegate know that the graph finished rendering
            if ([self.delegate respondsToSelector:@selector(lineGraphDidFinishDrawing:)])
                [self.delegate lineGraphDidFinishDrawing:self];
            return;
        }
    }
}

- (void)drawEntireGraph {
    // The following method calls are in this specific order for a reason
    // Changing the order of the method calls below can result in drawing glitches and even crashes

    self.maxValue = [self getMaximumValue];
    self.minValue = [self getMinimumValue];

    // Set the Y-Axis Offset if the Y-Axis is enabled. The offset is relative to the size of the longest label on the Y-Axis.
    if (self.enableYAxisLabel) {
        NSDictionary *attributes = @{NSFontAttributeName : self.labelFont};
        if (self.autoScaleYAxis == YES) {
            NSString *maxValueString = [NSString stringWithFormat:self.formatStringForValues, self.maxValue];
            NSString *minValueString = [NSString stringWithFormat:self.formatStringForValues, self.minValue];

            NSString *longestString = @"";
            if (maxValueString.length > minValueString.length)
                longestString = maxValueString;
            else
                longestString = minValueString;

            NSString *prefix = @"";
            NSString *suffix = @"";

            if ([self.delegate respondsToSelector:@selector(yAxisPrefixOnLineGraph:)]) {
                prefix = [self.delegate yAxisPrefixOnLineGraph:self];
            }

            if ([self.delegate respondsToSelector:@selector(yAxisSuffixOnLineGraph:)]) {
                suffix = [self.delegate yAxisSuffixOnLineGraph:self];
            }

            NSString *mString = [longestString stringByReplacingOccurrencesOfString:@"[0-9-]" withString:@"N" options:NSRegularExpressionSearch range:NSMakeRange(0, [longestString length])];
            NSString *fullString = [NSString stringWithFormat:@"%@%@%@", prefix, mString, suffix];
            self.YAxisLabelXOffset = [fullString sizeWithAttributes:attributes].width + 2; //MAX([maxValueString sizeWithAttributes:attributes].width + 10,
            //    [minValueString sizeWithAttributes:attributes].width) + 5;
        } else {
            NSString *longestString = [NSString stringWithFormat:@"%i", (int)self.frame.size.height];
            self.YAxisLabelXOffset = [longestString sizeWithAttributes:attributes].width + 5;
        }
    } else
        self.YAxisLabelXOffset = 0;

    // Draw the X-Axis
    [self drawXAxis];

    // Draw the graph
    [self drawDots];

    // Draw the Y-Axis
    if (self.enableYAxisLabel) {
        [self drawYAxis];
    }
}

- (void)drawDots {
    //    CGFloat positionOnXAxis; // The position on the X-axis of the point currently being created.
    CGFloat positionOnYAxis; // The position on the Y-axis of the point currently being created.

    // Remove all data points before adding them to the array
    [dataPoints removeAllObjects];

    // Remove all yAxis values before adding them to the array
    [yAxisValues removeAllObjects];

    // Loop through each point and add it to the graph
    @autoreleasepool {
        for (int i = 0; i < numberOfPoints; i++) {
            CGFloat dotValue = 0;

#if !TARGET_INTERFACE_BUILDER
            if ([self.dataSource respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                dotValue = [self.dataSource lineGraph:self valueForPointAtIndex:i];

            } else if ([self.delegate respondsToSelector:@selector(valueForIndex:)]) {
                [self printDeprecationWarningForOldMethod:@"valueForIndex:" andReplacementMethod:@"lineGraph:valueForPointAtIndex:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                dotValue = [self.delegate valueForIndex:i];
#pragma clang diagnostic pop

            } else if ([self.delegate respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                [self printDeprecationAndUnavailableWarningForOldMethod:@"lineGraph:valueForPointAtIndex:"];
                NSException *exception = [NSException exceptionWithName:@"Implementing Unavailable Delegate Method" reason:@"lineGraph:valueForPointAtIndex: is no longer available on the delegate. It must be implemented on the data source." userInfo:nil];
                [exception raise];


            } else
                [NSException raise:@"lineGraph:valueForPointAtIndex: protocol method is not implemented in the data source. Throwing exception here before the system throws a CALayerInvalidGeometry Exception." format:@"Value for point %f at index %lu is invalid. CALayer position may contain NaN: [0 nan]", dotValue, (unsigned long)i];
#else
            dotValue = (int)(arc4random() % 10000);
#endif
            [dataPoints addObject:[NSNumber numberWithFloat:dotValue]];
            positionOnYAxis = [self yPositionForDotValue:dotValue];
            [yAxisValues addObject:[NSNumber numberWithFloat:positionOnYAxis]];
        }
    }

    // CREATION OF THE LINE AND BOTTOM AND TOP FILL
    [self drawLine];
}

- (void)drawLine {
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[MTHLine class]])
            [subview removeFromSuperview];
    }

    if (_line == nil) {
        _line = [[MTHLine alloc] initWithFrame:[self drawableGraphArea]];
    }

    _line.opaque = NO;
    _line.alpha = 1;
    _line.backgroundColor = [UIColor clearColor];
    _line.topColor = self.colorTop;
    _line.bottomColor = self.colorBottom;
    _line.topAlpha = self.alphaTop;
    _line.bottomAlpha = self.alphaBottom;
    _line.topGradient = self.gradientTop;
    _line.bottomGradient = self.gradientBottom;
    _line.lineWidth = self.widthLine;
    _line.referenceLineWidth = self.widthReferenceLines ? self.widthReferenceLines : (self.widthLine / 2);
    _line.lineAlpha = self.alphaLine;
    _line.bezierCurveIsEnabled = self.enableBezierCurve;
    _line.arrayOfPoints = yAxisValues;
    _line.arrayOfValues = self.graphValuesForDataPoints;
    _line.lineDashPatternForReferenceYAxisLines = self.lineDashPatternForReferenceYAxisLines;
    _line.lineDashPatternForReferenceXAxisLines = self.lineDashPatternForReferenceXAxisLines;
    _line.interpolateNullValues = self.interpolateNullValues;

    _line.enableRefrenceFrame = self.enableReferenceAxisFrame;
    _line.enableRightReferenceFrameLine = self.enableRightReferenceAxisFrameLine;
    _line.enableTopReferenceFrameLine = self.enableTopReferenceAxisFrameLine;
    _line.enableLeftReferenceFrameLine = self.enableLeftReferenceAxisFrameLine;
    _line.enableBottomReferenceFrameLine = self.enableBottomReferenceAxisFrameLine;

    if (self.enableReferenceXAxisLines || self.enableReferenceYAxisLines) {
        _line.enableRefrenceLines = YES;
        _line.refrenceLineColor = self.colorReferenceLines;
        _line.verticalReferenceHorizontalFringeNegation = xAxisHorizontalFringeNegationValue;
        _line.arrayOfVerticalRefrenceLinePoints = self.enableReferenceXAxisLines ? xAxisLabelPoints : nil;
        _line.arrayOfHorizontalRefrenceLinePoints = self.enableReferenceYAxisLines ? yAxisLabelPoints : nil;
    }

    _line.color = self.colorLine;
    _line.lineGradient = self.gradientLine;
    _line.lineGradientDirection = self.gradientLineDirection;
    _line.animationTime = self.animationGraphEntranceTime;
    _line.animationType = self.animationGraphStyle;

    _line.disableMainLine = self.displayDotsOnly;

    [self addSubview:_line];
    [self sendSubviewToBack:_line];
    [self sendSubviewToBack:self.backgroundXAxis];

    [self didFinishDrawingIncludingYAxis:NO];
}

- (void)_drawXAxis {
    if (!self.enableXAxisLabel) return;
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]] && subview.tag == DotLastTag1000)
            [subview removeFromSuperview];
    }

    // Remove all X-Axis Labels before adding them to the array
    [xAxisValues removeAllObjects];
    [xAxisLabels removeAllObjects];
    [xAxisLabelPoints removeAllObjects];
    xAxisHorizontalFringeNegationValue = 0.0;

    // Draw X-Axis Background Area
    [self addBackgroundXAxis];
}

- (NSString *)timeStr {
    if (numberOfPoints < 3600) { //优先返回
        return [NSString stringWithFormat:@"%lds", (long)numberOfPoints];
    }
    if (numberOfPoints >= 3600 && numberOfPoints < 216000) { //1h之后显示多少分钟
        return [NSString stringWithFormat:@"%ldmin", (long)(numberOfPoints / 60)];
    } else {
        return [NSString stringWithFormat:@"%ldh", (long)(numberOfPoints / 3600)];
    }
}

- (void)drawXAxis {
    if (!self.enableXAxisLabel) return;
    if (![self.dataSource respondsToSelector:@selector(lineGraph:labelOnXAxisForIndex:)]) return;

    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]] && subview.tag == DotLastTag1000)
            [subview removeFromSuperview];
        else if ([subview isKindOfClass:[UIView class]] && subview.tag == BackgroundXAxisTag2200)
            [subview removeFromSuperview];
    }

    // Remove all X-Axis Labels before adding them to the array
    [xAxisValues removeAllObjects];
    [xAxisLabels removeAllObjects];
    [xAxisLabelPoints removeAllObjects];
    xAxisHorizontalFringeNegationValue = 0.0;

    // Draw X-Axis Background Area
    self.backgroundXAxis = [[UIView alloc] initWithFrame:[self drawableXAxisArea]];
    self.backgroundXAxis.tag = BackgroundXAxisTag2200;
    if (self.colorBackgroundXaxis == nil)
        self.backgroundXAxis.backgroundColor = self.colorBottom;
    else
        self.backgroundXAxis.backgroundColor = self.colorBackgroundXaxis;
    self.backgroundXAxis.alpha = self.alphaBackgroundXaxis;
    [self addSubview:self.backgroundXAxis];

    if ([self.delegate respondsToSelector:@selector(incrementPositionsForXAxisOnLineGraph:)]) {
        NSArray *axisValues = [self.delegate incrementPositionsForXAxisOnLineGraph:self];
        for (NSNumber *increment in axisValues) {
            NSInteger index = increment.integerValue;
            NSString *xAxisLabelText = [self xAxisTextForIndex:index];

            UILabel *labelXAxis = [self xAxisLabelWithText:xAxisLabelText atIndex:index];
            [xAxisLabels addObject:labelXAxis];

            if (self.positionYAxisRight) {
                NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x];
                [xAxisLabelPoints addObject:xAxisLabelCoordinate];
            } else {
                NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x - self.YAxisLabelXOffset];
                [xAxisLabelPoints addObject:xAxisLabelCoordinate];
            }

            [self addSubview:labelXAxis];
            [xAxisValues addObject:xAxisLabelText];
        }
    } else if ([self.delegate respondsToSelector:@selector(baseIndexForXAxisOnLineGraph:)] && [self.delegate respondsToSelector:@selector(incrementIndexForXAxisOnLineGraph:)]) {
        NSInteger baseIndex = [self.delegate baseIndexForXAxisOnLineGraph:self];
        NSInteger increment = [self.delegate incrementIndexForXAxisOnLineGraph:self];

        NSInteger startingIndex = baseIndex;
        while (startingIndex < numberOfPoints) {

            NSString *xAxisLabelText = [self xAxisTextForIndex:startingIndex];

            UILabel *labelXAxis = [self xAxisLabelWithText:xAxisLabelText atIndex:startingIndex];
            [xAxisLabels addObject:labelXAxis];

            if (self.positionYAxisRight) {
                NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x];
                [xAxisLabelPoints addObject:xAxisLabelCoordinate];
            } else {
                NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x - self.YAxisLabelXOffset];
                [xAxisLabelPoints addObject:xAxisLabelCoordinate];
            }

            [self addSubview:labelXAxis];
            [xAxisValues addObject:xAxisLabelText];

            startingIndex += increment;
        }
    } else {
        NSInteger numberOfGaps = 1;

        if ([self.delegate respondsToSelector:@selector(numberOfGapsBetweenLabelsOnLineGraph:)]) {
            numberOfGaps = [self.delegate numberOfGapsBetweenLabelsOnLineGraph:self] + 1;

        } else if ([self.delegate respondsToSelector:@selector(numberOfGapsBetweenLabels)]) {
            [self printDeprecationWarningForOldMethod:@"numberOfGapsBetweenLabels" andReplacementMethod:@"numberOfGapsBetweenLabelsOnLineGraph:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            numberOfGaps = [self.delegate numberOfGapsBetweenLabels] + 1;
#pragma clang diagnostic pop

        } else {
            numberOfGaps = 1;
        }

        if (numberOfGaps >= (numberOfPoints - 1)) {
            NSString *firstXLabel = [self xAxisTextForIndex:0];
            NSString *lastXLabel = [self xAxisTextForIndex:numberOfPoints - 1];

            CGFloat viewWidth = self.frame.size.width - self.YAxisLabelXOffset;

            CGFloat xAxisXPositionFirstOffset;
            CGFloat xAxisXPositionLastOffset;
            if (self.positionYAxisRight) {
                xAxisXPositionFirstOffset = 3;
                xAxisXPositionLastOffset = xAxisXPositionFirstOffset + 1 + viewWidth / 2;
            } else {
                xAxisXPositionFirstOffset = 3 + self.YAxisLabelXOffset;
                xAxisXPositionLastOffset = viewWidth / 2 + xAxisXPositionFirstOffset + 1;
            }
            UILabel *firstLabel = [self xAxisLabelWithText:firstXLabel atIndex:0];
            firstLabel.frame = CGRectMake(xAxisXPositionFirstOffset, self.frame.size.height - 20, viewWidth / 2, 20);

            firstLabel.textAlignment = NSTextAlignmentLeft;
            [self addSubview:firstLabel];
            [xAxisValues addObject:firstXLabel];
            [xAxisLabels addObject:firstLabel];

            UILabel *lastLabel = [self xAxisLabelWithText:lastXLabel atIndex:numberOfPoints - 1];
            lastLabel.frame = CGRectMake(xAxisXPositionLastOffset, self.frame.size.height - 20, viewWidth / 2 - 4, 20);
            lastLabel.textAlignment = NSTextAlignmentRight;
            [self addSubview:lastLabel];
            [xAxisValues addObject:lastXLabel];
            [xAxisLabels addObject:lastLabel];

            if (self.positionYAxisRight) {
                NSNumber *xFirstAxisLabelCoordinate = @(firstLabel.center.x);
                NSNumber *xLastAxisLabelCoordinate = @(lastLabel.center.x);
                [xAxisLabelPoints addObject:xFirstAxisLabelCoordinate];
                [xAxisLabelPoints addObject:xLastAxisLabelCoordinate];
            } else {
                NSNumber *xFirstAxisLabelCoordinate = @(firstLabel.center.x - self.YAxisLabelXOffset);
                NSNumber *xLastAxisLabelCoordinate = @(lastLabel.center.x - self.YAxisLabelXOffset);
                [xAxisLabelPoints addObject:xFirstAxisLabelCoordinate];
                [xAxisLabelPoints addObject:xLastAxisLabelCoordinate];
            }
        } else {
            @autoreleasepool {
                NSInteger offset = [self offsetForXAxisWithNumberOfGaps:numberOfGaps]; // The offset (if possible and necessary) used to shift the Labels on the X-Axis for them to be centered.

                for (int i = 1; i <= (numberOfPoints / numberOfGaps); i++) {
                    NSInteger index = i * numberOfGaps - 1 - offset;
                    NSString *xAxisLabelText = [self xAxisTextForIndex:index];

                    UILabel *labelXAxis = [self xAxisLabelWithText:xAxisLabelText atIndex:index];
                    [xAxisLabels addObject:labelXAxis];

                    if (self.positionYAxisRight) {
                        NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x];
                        [xAxisLabelPoints addObject:xAxisLabelCoordinate];
                    } else {
                        NSNumber *xAxisLabelCoordinate = [NSNumber numberWithFloat:labelXAxis.center.x - self.YAxisLabelXOffset];
                        [xAxisLabelPoints addObject:xAxisLabelCoordinate];
                    }

                    [self addSubview:labelXAxis];
                    [xAxisValues addObject:xAxisLabelText];
                }
            }
        }
    }
    __block NSUInteger lastMatchIndex;

    NSMutableArray *overlapLabels = [NSMutableArray arrayWithCapacity:0];
    [xAxisLabels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            lastMatchIndex = 0;
        } else { // Skip first one
            UILabel *prevLabel = [self->xAxisLabels objectAtIndex:lastMatchIndex];
            CGRect r = CGRectIntersection(prevLabel.frame, label.frame);
            if (CGRectIsNull(r))
                lastMatchIndex = idx;
            else
                [overlapLabels addObject:label]; // Overlapped
        }

        BOOL fullyContainsLabel = CGRectContainsRect(self.bounds, label.frame);
        if (!fullyContainsLabel) {
            [overlapLabels addObject:label];
        }
    }];

    for (UILabel *l in overlapLabels) {
        [l removeFromSuperview];
    }
}

- (NSString *)xAxisTextForIndex:(NSInteger)index {
    NSString *xAxisLabelText = @"";

    if ([self.dataSource respondsToSelector:@selector(lineGraph:labelOnXAxisForIndex:)]) {
        xAxisLabelText = [self.dataSource lineGraph:self labelOnXAxisForIndex:index];

    } else if ([self.delegate respondsToSelector:@selector(labelOnXAxisForIndex:)]) {
        [self printDeprecationWarningForOldMethod:@"labelOnXAxisForIndex:" andReplacementMethod:@"lineGraph:labelOnXAxisForIndex:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        xAxisLabelText = [self.delegate labelOnXAxisForIndex:index];
#pragma clang diagnostic pop

    } else if ([self.delegate respondsToSelector:@selector(lineGraph:labelOnXAxisForIndex:)]) {
        [self printDeprecationAndUnavailableWarningForOldMethod:@"lineGraph:labelOnXAxisForIndex:"];
        NSException *exception = [NSException exceptionWithName:@"Implementing Unavailable Delegate Method" reason:@"lineGraph:labelOnXAxisForIndex: is no longer available on the delegate. It must be implemented on the data source." userInfo:nil];
        [exception raise];

    } else {
        xAxisLabelText = @"";
    }

    return xAxisLabelText;
}

- (UILabel *)xAxisLabelWithText:(NSString *)text atIndex:(NSInteger)index {
    UILabel *labelXAxis = [[UILabel alloc] init];
    labelXAxis.text = text;
    labelXAxis.font = self.labelFont;
    labelXAxis.textAlignment = 1;
    labelXAxis.textColor = self.colorXaxisLabel;
    labelXAxis.backgroundColor = [UIColor clearColor];
    labelXAxis.tag = DotLastTag1000;

    // Add support multi-line, but this might overlap with the graph line if text have too many lines
    labelXAxis.numberOfLines = 0;
    CGRect lRect = [labelXAxis.text boundingRectWithSize:self.viewForBaselineLayout.frame.size options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : labelXAxis.font} context:nil];

    CGPoint center;

    /* OLD LABEL GENERATION CODE
     CGFloat availablePositionRoom = self.viewForBaselineLayout.frame.size.width; // Get view width of view
     CGFloat positioningDivisor = (float)index / numberOfPoints; // Generate relative position of point based on current index and total
     CGFloat horizontalTranslation = self.YAxisLabelXOffset + lRect.size.width;
     CGFloat xPosition = (availablePositionRoom * positioningDivisor) + horizontalTranslation;
     // NSLog(@"availablePositionRoom: %f, positioningDivisor: %f, horizontalTranslation: %f, xPosition: %f", availablePositionRoom, positioningDivisor, horizontalTranslation, xPosition); // Uncomment for debugging */

    // Determine the horizontal translation to perform on the far left and far right labels
    // This property is negated when calculating the position of reference frames
    CGFloat horizontalTranslation;
    if (index == 0) {
        horizontalTranslation = lRect.size.width / 2;
    } else if (index + 1 == numberOfPoints) {
        horizontalTranslation = -lRect.size.width / 2;
    } else
        horizontalTranslation = 0;
    xAxisHorizontalFringeNegationValue = horizontalTranslation;

    // Determine the final x-axis position
    CGFloat positionOnXAxis;
    if (self.positionYAxisRight) {
        positionOnXAxis = (((self.frame.size.width - self.YAxisLabelXOffset) / (numberOfPoints - 1)) * index) + horizontalTranslation;
    } else {
        positionOnXAxis = (((self.frame.size.width - self.YAxisLabelXOffset) / (numberOfPoints - 1)) * index) + self.YAxisLabelXOffset + horizontalTranslation;
    }

    // Set the final center point of the x-axis labels
    if (self.positionYAxisRight) {
        center = CGPointMake(positionOnXAxis, self.frame.size.height - lRect.size.height / 2);
    } else {
        center = CGPointMake(positionOnXAxis, self.frame.size.height - lRect.size.height / 2);
    }

    CGRect rect = labelXAxis.frame;
    rect.size = lRect.size;
    labelXAxis.frame = rect;
    labelXAxis.center = center;
    return labelXAxis;
}

- (void)drawYAxis {
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]] && subview.tag == LabelYAxisTag2000) {
            [subview removeFromSuperview];
        } else if ([subview isKindOfClass:[UIView class]] && subview.tag == BackgroundYAxisTag2100) {
            [subview removeFromSuperview];
        }
    }

    CGRect frameForBackgroundYAxis;
    CGRect frameForLabelYAxis;
    CGFloat xValueForCenterLabelYAxis;
    NSTextAlignment textAlignmentForLabelYAxis;

    if (self.positionYAxisRight) {
        frameForBackgroundYAxis = CGRectMake(self.frame.size.width - self.YAxisLabelXOffset, 0, self.YAxisLabelXOffset, self.frame.size.height);
        frameForLabelYAxis = CGRectMake(self.frame.size.width - self.YAxisLabelXOffset - 5, 0, self.YAxisLabelXOffset - 5, 15);
        xValueForCenterLabelYAxis = self.frame.size.width - self.YAxisLabelXOffset / 2;
        textAlignmentForLabelYAxis = NSTextAlignmentRight;
    } else {
        frameForBackgroundYAxis = CGRectMake(0, 0, self.YAxisLabelXOffset, self.frame.size.height);
        frameForLabelYAxis = CGRectMake(0, 0, self.YAxisLabelXOffset - 5, 15);
        xValueForCenterLabelYAxis = self.YAxisLabelXOffset / 2;
        textAlignmentForLabelYAxis = NSTextAlignmentRight;
    }

    if (_backgroundYaxis == nil) {
        _backgroundYaxis = [[UIView alloc] initWithFrame:frameForBackgroundYAxis];
    }
    _backgroundYaxis.tag = BackgroundYAxisTag2100;
    if (self.colorBackgroundYaxis == nil)
        _backgroundYaxis.backgroundColor = self.colorTop;
    else
        _backgroundYaxis.backgroundColor = self.colorBackgroundYaxis;
    _backgroundYaxis.alpha = self.alphaBackgroundYaxis;
    [self addSubview:_backgroundYaxis];

    NSMutableArray *yAxisLabels = [NSMutableArray arrayWithCapacity:0];
    [yAxisLabelPoints removeAllObjects];

    NSString *yAxisSuffix = @"";
    NSString *yAxisPrefix = @"";

    if ([self.delegate respondsToSelector:@selector(yAxisPrefixOnLineGraph:)]) yAxisPrefix = [self.delegate yAxisPrefixOnLineGraph:self];
    if ([self.delegate respondsToSelector:@selector(yAxisSuffixOnLineGraph:)]) yAxisSuffix = [self.delegate yAxisSuffixOnLineGraph:self];

    if (self.autoScaleYAxis) {
        // Plot according to min-max range
        NSNumber *minimumValue;
        NSNumber *maximumValue;

        minimumValue = [self calculateMinimumPointValue];
        maximumValue = [self calculateMaximumPointValue];

        CGFloat numberOfLabels;
        if ([self.delegate respondsToSelector:@selector(numberOfYAxisLabelsOnLineGraph:)]) {
            numberOfLabels = [self.delegate numberOfYAxisLabelsOnLineGraph:self];
        } else
            numberOfLabels = 3;

        NSMutableArray *dotValues = [[NSMutableArray alloc] initWithCapacity:numberOfLabels];
        if ([self.delegate respondsToSelector:@selector(baseValueForYAxisOnLineGraph:)] && [self.delegate respondsToSelector:@selector(incrementValueForYAxisOnLineGraph:)]) {
            CGFloat baseValue = [self.delegate baseValueForYAxisOnLineGraph:self];
            CGFloat increment = [self.delegate incrementValueForYAxisOnLineGraph:self];

            float yAxisPosition = baseValue;
            if (baseValue + increment * 100 < maximumValue.doubleValue) {
                NSLog(@"[MTHSimpleLineGraph] Increment does not properly lay out Y axis, bailing early");
                return;
            }

            while (yAxisPosition < maximumValue.floatValue + increment) {
                [dotValues addObject:@(yAxisPosition)];
                yAxisPosition += increment;
            }
        } else if (numberOfLabels <= 0)
            return;
        else if (numberOfLabels == 1) {
            [dotValues removeAllObjects];
            [dotValues addObject:[NSNumber numberWithInt:(minimumValue.intValue + maximumValue.intValue) / 2]];
        } else {
            [dotValues addObject:minimumValue];
            [dotValues addObject:maximumValue];
            for (int i = 1; i < numberOfLabels - 1; i++) {
                [dotValues addObject:[NSNumber numberWithFloat:(minimumValue.doubleValue + ((maximumValue.doubleValue - minimumValue.doubleValue) / (numberOfLabels - 1)) * i)]];
            }
        }
        // 这里如果值都相同，绘制一个平均的label就可以了
        NSNumber *dotFloat = dotValues[0];
        CGFloat yMinAxisPosition = [self yPositionForDotValue:dotFloat.floatValue];
        if (_minYAxisLabel == nil) {
            _minYAxisLabel = [[UILabel alloc] initWithFrame:frameForLabelYAxis];
        }
        NSString *formattedValue = [NSString stringWithFormat:self.formatStringForValues, dotFloat.doubleValue];
        _minYAxisLabel.text = [NSString stringWithFormat:@"%@%@%@", yAxisPrefix, formattedValue, yAxisSuffix];
        _minYAxisLabel.textAlignment = textAlignmentForLabelYAxis;
        _minYAxisLabel.font = self.labelFont;
        _minYAxisLabel.textColor = self.colorYaxisLabel;
        _minYAxisLabel.backgroundColor = [UIColor clearColor];
        _minYAxisLabel.tag = LabelYAxisTag2000;
        _minYAxisLabel.center = CGPointMake(xValueForCenterLabelYAxis, yMinAxisPosition);
        [self addSubview:_minYAxisLabel];
        [yAxisLabels addObject:_minYAxisLabel];
        NSNumber *dotMaxFloat = dotValues[1] ? dotValues[1] : @0;
        CGFloat yMaxAxisPosition = [self yPositionForDotValue:dotMaxFloat.floatValue];
        if (_maxYAxisLabel == nil) {
            _maxYAxisLabel = [[UILabel alloc] initWithFrame:frameForLabelYAxis];
        }
        NSString *formattedMaxValue = [NSString stringWithFormat:self.formatStringForValues, dotMaxFloat.doubleValue];
        _maxYAxisLabel.text = [NSString stringWithFormat:@"%@%@%@", yAxisPrefix, formattedMaxValue, yAxisSuffix];
        _maxYAxisLabel.textAlignment = textAlignmentForLabelYAxis;
        _maxYAxisLabel.font = self.labelFont;
        _maxYAxisLabel.textColor = self.colorYaxisLabel;
        _maxYAxisLabel.backgroundColor = [UIColor clearColor];
        _maxYAxisLabel.tag = LabelYAxisTag2000;
        _maxYAxisLabel.center = CGPointMake(xValueForCenterLabelYAxis, yMaxAxisPosition);
        [self addSubview:_maxYAxisLabel];
        [yAxisLabels addObject:_maxYAxisLabel];
        NSNumber *dotAveFloat = dotValues[2] ? dotValues[2] : @0;
        CGFloat yAveAxisPosition = [self yPositionForDotValue:dotAveFloat.floatValue];
        if (_aveYAxisLabel == nil) {
            _aveYAxisLabel = [[UILabel alloc] initWithFrame:frameForLabelYAxis];
        }
        NSString *formattedAveValue = [NSString stringWithFormat:self.formatStringForValues, dotAveFloat.doubleValue];
        _aveYAxisLabel.text = [NSString stringWithFormat:@"%@%@%@", yAxisPrefix, formattedAveValue, yAxisSuffix];
        _aveYAxisLabel.textAlignment = textAlignmentForLabelYAxis;
        _aveYAxisLabel.font = self.labelFont;
        _aveYAxisLabel.textColor = self.colorYaxisLabel;
        _aveYAxisLabel.backgroundColor = [UIColor clearColor];
        _aveYAxisLabel.tag = LabelYAxisTag2000;
        _aveYAxisLabel.center = CGPointMake(xValueForCenterLabelYAxis, yAveAxisPosition);
        [self addSubview:_aveYAxisLabel];
        [yAxisLabels addObject:_aveYAxisLabel];
        // 这里可能存在只有一个 label 的情况
        if ([dotAveFloat integerValue] == [dotFloat integerValue] == [dotMaxFloat integerValue]) {
            [_minYAxisLabel removeFromSuperview];
            [_maxYAxisLabel removeFromSuperview];
        }
    }
    // Detect overlapped labels
    __block NSUInteger lastMatchIndex = 0;
    NSMutableArray *overlapLabels = [NSMutableArray arrayWithCapacity:0];

    [yAxisLabels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger idx, BOOL *stop) {
        if (idx == 0)
            lastMatchIndex = 0;
        else { // Skip first one
            UILabel *prevLabel = yAxisLabels[lastMatchIndex];
            CGRect r = CGRectIntersection(prevLabel.frame, label.frame);
            if (CGRectIsNull(r))
                lastMatchIndex = idx;
            else
                [overlapLabels addObject:label]; // overlapped
        }

        // Axis should fit into our own view
        BOOL fullyContainsLabel = CGRectContainsRect(self.bounds, label.frame);
        if (!fullyContainsLabel) {
            [overlapLabels addObject:label];
            [self->yAxisLabelPoints removeObject:@(label.center.y)];
        }
    }];

    for (UILabel *label in overlapLabels) {
        [label removeFromSuperview];
    }

    [self didFinishDrawingIncludingYAxis:YES];
}

/// Area on the graph that doesn't include the axes
- (CGRect)drawableGraphArea {
    //  CGRectMake(xAxisXPositionFirstOffset, self.frame.size.height-20, viewWidth/2, 20);
    NSInteger xAxisHeight = 20;
    CGFloat xOrigin = self.positionYAxisRight ? 0 : self.YAxisLabelXOffset;
    CGFloat viewWidth = self.frame.size.width - self.YAxisLabelXOffset;
    CGFloat adjustedHeight = self.bounds.size.height - xAxisHeight;

    CGRect rect = CGRectMake(xOrigin, 0, viewWidth, adjustedHeight);
    return rect;
}

- (CGRect)drawableXAxisArea {
    NSInteger xAxisHeight = 20;
    NSInteger xAxisWidth = [self drawableGraphArea].size.width + 1;
    CGFloat xAxisXOrigin = self.positionYAxisRight ? 0 : self.YAxisLabelXOffset;
    CGFloat xAxisYOrigin = self.bounds.size.height - xAxisHeight;
    return CGRectMake(xAxisXOrigin, xAxisYOrigin, xAxisWidth, xAxisHeight);
}

/// Calculates the optimum offset needed for the Labels to be centered on the X-Axis.
- (NSInteger)offsetForXAxisWithNumberOfGaps:(NSInteger)numberOfGaps {
    NSInteger leftGap = numberOfGaps - 1;
    NSInteger rightGap = numberOfPoints - (numberOfGaps * (numberOfPoints / numberOfGaps));
    NSInteger offset = 0;

    if (leftGap != rightGap) {
        for (int i = 0; i <= numberOfGaps; i++) {
            if (leftGap - i == rightGap + i) {
                offset = i;
            }
        }
    }

    return offset;
}

- (BOOL)checkOverlapsForView:(UIView *)view {
    for (UIView *viewForLabel in [self subviews]) {
        if ([viewForLabel isKindOfClass:[UIView class]] && viewForLabel.tag == PermanentPopUpViewTag3100) {
            if ((viewForLabel.frame.origin.x + viewForLabel.frame.size.width) >= view.frame.origin.x) {
                if (viewForLabel.frame.origin.y >= view.frame.origin.y && viewForLabel.frame.origin.y <= view.frame.origin.y + view.frame.size.height)
                    return YES;
                else if (viewForLabel.frame.origin.y + viewForLabel.frame.size.height >= view.frame.origin.y && viewForLabel.frame.origin.y + viewForLabel.frame.size.height <= view.frame.origin.y + view.frame.size.height)
                    return YES;
            }
        }
    }
    return NO;
}

- (UIImage *)graphSnapshotImage {
    return [self graphSnapshotImageRenderedWhileInBackground:NO];
}

- (UIImage *)graphSnapshotImageRenderedWhileInBackground:(BOOL)appIsInBackground {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);

    if (appIsInBackground == NO) {
        [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    } else {
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (context)
            [self.layer renderInContext:context];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

#pragma mark - Data Source

- (void)reloadGraph {
    if (_isGraphSelected) {
        return;
    }
    for (UIView *subviews in self.subviews) {
        if (subviews.tag != PanViewTag4000 && subviews.tag != BackgroundXAxisTag2200) {
            [subviews removeFromSuperview];
        }
    }
    [self drawGraph];
    //    [self setNeedsLayout];
}

#pragma mark - Calculations

- (NSArray *)calculationDataPoints {
    NSPredicate *filter = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSNumber *value = (NSNumber *)evaluatedObject;
        BOOL retVal = ![value isEqualToNumber:@(MTHNullGraphValue)];
        return retVal;
    }];
    NSArray *filteredArray = [dataPoints filteredArrayUsingPredicate:filter];
    return filteredArray;
}

- (NSNumber *)calculatePointValueAverage {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"average:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];

    return value;
}

- (NSNumber *)calculatePointValueSum {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"sum:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];

    return value;
}

- (NSNumber *)calculatePointValueMedian {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"median:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];

    return value;
}

- (NSNumber *)calculatePointValueMode {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"mode:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSMutableArray *value = [expression expressionValueWithObject:nil context:nil];

    return [value firstObject];
}

- (NSNumber *)calculateLineGraphStandardDeviation {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"stddev:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];

    return value;
}

- (NSNumber *)calculateMinimumPointValue {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"min:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];
    return value;
}

- (NSNumber *)calculateMaximumPointValue {
    NSArray *filteredArray = [self calculationDataPoints];
    if (filteredArray.count == 0) return [NSNumber numberWithInt:0];

    NSExpression *expression = [NSExpression expressionForFunction:@"max:" arguments:@[ [NSExpression expressionForConstantValue:filteredArray] ]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];

    return value;
}


#pragma mark - Values

- (NSArray *)graphValuesForXAxis {
    return xAxisValues;
}

- (NSArray *)graphValuesForDataPoints {
    return dataPoints;
}

- (NSArray *)graphLabelsForXAxis {
    return xAxisLabels;
}

- (void)setAnimationGraphStyle:(MTHLineAnimation)animationGraphStyle {
    _animationGraphStyle = animationGraphStyle;
    if (_animationGraphStyle == MTHLineAnimationNone)
        self.animationGraphEntranceTime = 0.f;
}


#pragma mark - Touch Gestures

//- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
//    if ([gestureRecognizer isEqual:self.panGesture]) {
//        if (gestureRecognizer.numberOfTouches >= self.touchReportFingersRequired) {
//            CGPoint translation = [self.panGesture velocityInView:self.panView];
//            return fabs(translation.y) < fabs(translation.x);
//        } else
//            return NO;
//        return YES;
//    } else
//        return NO;
//}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (void)handleGestureAction:(UIGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer locationInView:self.viewForBaselineLayout];

    if (!((translation.x + self.frame.origin.x) <= self.frame.origin.x) && !((translation.x + self.frame.origin.x) >= self.frame.origin.x + self.frame.size.width)) { // To make sure the vertical line doesn't go beyond the frame of the graph.
        self.touchInputLine.frame = CGRectMake(translation.x - self.widthTouchInputLine / 2, 0, self.widthTouchInputLine, self.frame.size.height);
    }

    self.touchInputLine.alpha = self.alphaTouchInputLine;
    //
    //    closestDot = [self closestDotFromtouchInputLine:self.touchInputLine];
    //    closestDot.alpha = 0.8;
    //
    //
    //    if (self.enablePopUpReport == YES && closestDot.tag >= DotFirstTag100 && closestDot.tag < DotLastTag1000 && [closestDot isKindOfClass:[MTHCircle class]] && self.alwaysDisplayPopUpLabels == NO) {
    //        [self setUpPopUpLabelAbovePoint:closestDot];
    //    }
    //
    //    if (closestDot.tag >= DotFirstTag100 && closestDot.tag < DotLastTag1000 && [closestDot isMemberOfClass:[MTHCircle class]]) {
    //        if ([self.delegate respondsToSelector:@selector(lineGraph:didTouchGraphWithClosestIndex:)] && self.enableTouchReport == YES) {
    //            [self.delegate lineGraph:self didTouchGraphWithClosestIndex:((NSInteger)closestDot.tag - DotFirstTag100)];
    //
    //        } else if ([self.delegate respondsToSelector:@selector(didTouchGraphWithClosestIndex:)] && self.enableTouchReport == YES) {
    //            [self printDeprecationWarningForOldMethod:@"didTouchGraphWithClosestIndex:" andReplacementMethod:@"lineGraph:didTouchGraphWithClosestIndex:"];
    //
    //#pragma clang diagnostic push
    //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //            [self.delegate didTouchGraphWithClosestIndex:((int)closestDot.tag - DotFirstTag100)];
    //#pragma clang diagnostic pop
    //        }
    //    }

    // ON RELEASE
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([self.delegate respondsToSelector:@selector(lineGraph:didReleaseTouchFromGraphWithClosestIndex:)]) {
            //            [self.delegate lineGraph:self didReleaseTouchFromGraphWithClosestIndex:(closestDot.tag - DotFirstTag100)];

        } else if ([self.delegate respondsToSelector:@selector(didReleaseGraphWithClosestIndex:)]) {
            [self printDeprecationWarningForOldMethod:@"didReleaseGraphWithClosestIndex:" andReplacementMethod:@"lineGraph:didReleaseTouchFromGraphWithClosestIndex:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//            [self.delegate didReleaseGraphWithClosestIndex:(closestDot.tag - DotFirstTag100)];
#pragma clang diagnostic pop
        }

        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (self.alwaysDisplayDots == NO && self.displayDotsOnly == NO) {
                                 //                                 closestDot.alpha = 0;
                             }

                             self.touchInputLine.alpha = 0;
                             if (self.enablePopUpReport == YES) {
                                 self.popUpView.alpha = 0;
                                 self.popUpLabel.alpha = 0;
                                 //                self.customPopUpView.alpha = 0;
                             }
                         }
                         completion:nil];
    }
}

- (CGFloat)distanceToClosestPoint {
    return 0.f;
    //    return sqrt(pow(closestDot.center.x - self.touchInputLine.center.x, 2));
}

//- (void)setUpPopUpLabelAbovePoint:(MTHCircle *)closestPoint {
//    self.xCenterLabel = closestDot.center.x;
//    self.yCenterLabel = closestDot.center.y - closestDot.frame.size.height / 2 - 15;
//    self.popUpView.center = CGPointMake(self.xCenterLabel, self.yCenterLabel);
//    self.popUpLabel.center = self.popUpView.center;
//    int index = (int)(closestDot.tag - DotFirstTag100);
//
//    if ([self.delegate respondsToSelector:@selector(lineGraph:modifyPopupView:forIndex:)]) {
//        [self.delegate lineGraph:self modifyPopupView:self.popUpView forIndex:index];
//    }
//    self.xCenterLabel = closestDot.center.x;
//    self.yCenterLabel = closestDot.center.y - closestDot.frame.size.height / 2 - 15;
//    self.popUpView.center = CGPointMake(self.xCenterLabel, self.yCenterLabel);
//
//    self.popUpView.alpha = 1.0;
//
//    CGPoint popUpViewCenter = CGPointZero;
//
//    if ([self.delegate respondsToSelector:@selector(popUpSuffixForlineGraph:)])
//        self.popUpLabel.text = [NSString stringWithFormat:@"%li%@", (long)[dataPoints[(NSInteger)closestDot.tag - DotFirstTag100] integerValue], [self.delegate popUpSuffixForlineGraph:self]];
//    else
//        self.popUpLabel.text = [NSString stringWithFormat:@"%li", (long)[dataPoints[(NSInteger)closestDot.tag - DotFirstTag100] integerValue]];
//
//    if (self.enableYAxisLabel == YES && self.popUpView.frame.origin.x <= self.YAxisLabelXOffset && !self.positionYAxisRight) {
//        self.xCenterLabel = self.popUpView.frame.size.width / 2;
//        popUpViewCenter = CGPointMake(self.xCenterLabel + self.YAxisLabelXOffset + 1, self.yCenterLabel);
//    } else if ((self.popUpView.frame.origin.x + self.popUpView.frame.size.width) >= self.frame.size.width - self.YAxisLabelXOffset && self.positionYAxisRight) {
//        self.xCenterLabel = self.frame.size.width - self.popUpView.frame.size.width / 2;
//        popUpViewCenter = CGPointMake(self.xCenterLabel - self.YAxisLabelXOffset, self.yCenterLabel);
//    } else if (self.popUpView.frame.origin.x <= 0) {
//        self.xCenterLabel = self.popUpView.frame.size.width / 2;
//        popUpViewCenter = CGPointMake(self.xCenterLabel, self.yCenterLabel);
//    } else if ((self.popUpView.frame.origin.x + self.popUpView.frame.size.width) >= self.frame.size.width) {
//        self.xCenterLabel = self.frame.size.width - self.popUpView.frame.size.width / 2;
//        popUpViewCenter = CGPointMake(self.xCenterLabel, self.yCenterLabel);
//    }
//
//    if (self.popUpView.frame.origin.y <= 2) {
//        self.yCenterLabel = closestDot.center.y + closestDot.frame.size.height / 2 + 15;
//        popUpViewCenter = CGPointMake(self.xCenterLabel, closestDot.center.y + closestDot.frame.size.height / 2 + 15);
//    }
//
//    if (!CGPointEqualToPoint(popUpViewCenter, CGPointZero)) {
//        self.popUpView.center = popUpViewCenter;
//    }
//
//    if (!self.usingCustomPopupView) {
//        [UIView animateWithDuration:0.2
//                              delay:0
//                            options:UIViewAnimationOptionCurveEaseOut
//                         animations:^{
//                             self.popUpView.alpha = 0.7;
//                             self.popUpLabel.alpha = 1;
//                         }
//                         completion:nil];
//        NSString *prefix = @"";
//        NSString *suffix = @"";
//        if ([self.delegate respondsToSelector:@selector(popUpSuffixForlineGraph:)]) {
//            suffix = [self.delegate popUpSuffixForlineGraph:self];
//        }
//        if ([self.delegate respondsToSelector:@selector(popUpPrefixForlineGraph:)]) {
//            prefix = [self.delegate popUpPrefixForlineGraph:self];
//        }
//        NSNumber *value = dataPoints[index];
//        NSString *formattedValue = [NSString stringWithFormat:self.formatStringForValues, value.doubleValue];
//        self.popUpLabel.text = [NSString stringWithFormat:@"%@%@%@", prefix, formattedValue, suffix];
//        self.popUpLabel.center = self.popUpView.center;
//    }
//}


- (void)tapHandlerForLine:(UIGestureRecognizer *)recognizer {
    [self reloadGraphSelectedState:YES];
    //set value

    CGFloat offset = (_panView.frame.size.width - _widthTouchInputLine) / (numberOfPoints - 1);
    CGFloat plo = _leftTouchLine.frame.origin.x / offset; // px占多少格
    plo = [self nearestIndexForPointx:plo];
    [_leftTouchLine setValueForNumberLabel:dataPoints[(int)plo]];

    CGFloat pro = _rightTouchLine.frame.origin.x / offset; // px占多少格
    pro = [self nearestIndexForPointx:pro];
    [_rightTouchLine setValueForNumberLabel:dataPoints[(int)pro]];

    _leftSelectedIdx = pro > plo ? plo : pro;
    _rightSelectedIdx = pro > plo ? pro : plo;

    if ([self delegateValidForSEL:@selector(rangeSelectEnableForLineGraph:)] &&
        [self delegateValidForSEL:@selector(lineGraph:didSelectedWithIndexRange:)] &&
        [self.delegate rangeSelectEnableForLineGraph:self] && _leftSelectedIdx != _rightSelectedIdx) {
        NSRange selectedRange = NSMakeRange(_leftSelectedIdx, _rightSelectedIdx - _leftSelectedIdx);
        [self.delegate lineGraph:self didSelectedWithIndexRange:selectedRange];
    }
}

- (void)panHandlerForLine:(UIPanGestureRecognizer *)recognizer {

    MTHTouchLineView *leftLine = _leftTouchLine.frame.origin.x <= _rightTouchLine.frame.origin.x ? _leftTouchLine : _rightTouchLine;
    MTHTouchLineView *rightLine = _leftTouchLine.frame.origin.x <= _rightTouchLine.frame.origin.x ? _rightTouchLine : _leftTouchLine;
    UIView *leftControl = leftLine == _leftTouchLine ? [self viewWithTag:kTagBaseForLineController] : [self viewWithTag:kTagBaseForLineController + 1];
    UIView *rightControl = rightLine == _rightTouchLine ? [self viewWithTag:kTagBaseForLineController + 1] : [self viewWithTag:kTagBaseForLineController];

    float leftLineX = _leftTouchLine.frame.origin.x <= _rightTouchLine.frame.origin.x ? _leftTouchLine.frame.origin.x : _rightTouchLine.frame.origin.x;
    float rightLineX = _leftTouchLine.frame.origin.x >= _rightTouchLine.frame.origin.x ? _leftTouchLine.frame.origin.x : _rightTouchLine.frame.origin.x;

    CGFloat panX = [self pointXInScope:[recognizer locationInView:self.panView].x];
    // __unused CGPoint panVelocity = [recognizer velocityInView:recognizer.view];
    float panNearToLeftView = fabs(panX - leftLineX);
    float panNearToRightView = fabs(panX - rightLineX);

    // 每一格在图中占的长度
    CGFloat offset = (_panView.frame.size.width - _widthTouchInputLine) / (numberOfPoints - 1);
    NSInteger panIndex = [self nearestIndexForPointx:panX / offset];
    CGRect frame = CGRectMake(panX, 0, _widthTouchInputLine, self.frame.size.height);
    [self reloadGraphSelectedState:YES];

    if (panNearToLeftView < panNearToRightView) {
        [leftLine setValueForNumberLabel:dataPoints[panIndex]];
        leftLine.frame = frame;
        [leftLine reloadNumLabelFrameWithMaxWidth:_panView.frame.size.width];
        _leftSelectedIdx = panIndex;
        leftControl.frame = CGRectMake(panX - leftControl.frame.size.width / 2, leftControl.frame.origin.y, leftControl.frame.size.width, leftControl.frame.size.height);

        // 创建时右侧拨片视图位置不为0，需要初始化下 rightIndex
        if (_rightSelectedIdx == 0 && !_haveInitSelctedIndex) {
            _haveInitSelctedIndex = YES;
            UIView *rightRangePickV = [self viewWithTag:kTagBaseForLineController + 1];
            CGFloat rightRangePickVOffset = (rightRangePickV.frame.size.width - _widthTouchInputLine) / (numberOfPoints - 1);
            _rightSelectedIdx = [self nearestIndexForPointx:rightRangePickV.center.x / rightRangePickVOffset];
        }
    } else {
        [rightLine setValueForNumberLabel:dataPoints[panIndex]];
        rightLine.frame = frame;
        [rightLine reloadNumLabelFrameWithMaxWidth:_panView.frame.size.width];
        _rightSelectedIdx = panIndex;
        rightControl.frame = CGRectMake(panX - rightControl.frame.size.width / 2, rightControl.frame.origin.y, rightControl.frame.size.width, rightControl.frame.size.height);

        // 创建时左侧拨片视图位置不为0，需要初始化下 leftIndex
        if (_leftSelectedIdx == 0 && !_haveInitSelctedIndex) {
            _haveInitSelctedIndex = YES;
            UIView *leftRangePickV = [self viewWithTag:kTagBaseForLineController + 0];
            CGFloat leftRangePickVOffset = (leftRangePickV.frame.size.width - _widthTouchInputLine) / (numberOfPoints - 1);
            _rightSelectedIdx = [self nearestIndexForPointx:leftRangePickV.center.x / leftRangePickVOffset];
        }
    }

    if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
        CGFloat panOffst = panIndex * offset;
        if (panNearToLeftView < panNearToRightView) {
            [UIView animateWithDuration:0.1
                                  delay:0
                 usingSpringWithDamping:1
                  initialSpringVelocity:5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 leftLine.frame = CGRectMake(panOffst, 0, self->_widthTouchInputLine, self.frame.size.height);
                                 leftControl.frame = CGRectMake(panOffst - leftControl.frame.size.width / 2, leftControl.frame.origin.y, leftControl.frame.size.width, leftControl.frame.size.height);
                             }
                             completion:nil];
        } else {
            [UIView animateWithDuration:0.1
                                  delay:0
                 usingSpringWithDamping:1
                  initialSpringVelocity:5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 rightLine.frame = CGRectMake(panOffst, 0, self->_widthTouchInputLine, self.frame.size.height);
                                 rightControl.frame = CGRectMake(panOffst - rightControl.frame.size.width / 2, rightControl.frame.origin.y, rightControl.frame.size.width, rightControl.frame.size.height);
                             }
                             completion:nil];
        }

        [self reloadGraphSelectedState:YES];

        // 保证左边的更小
        if (_leftSelectedIdx > _rightSelectedIdx) {
            NSInteger tmp = _leftSelectedIdx;
            _leftSelectedIdx = _rightSelectedIdx;
            _rightSelectedIdx = tmp;
        }

        if ([self delegateValidForSEL:@selector(rangeSelectEnableForLineGraph:)] &&
            [self delegateValidForSEL:@selector(lineGraph:didSelectedWithIndexRange:)] &&
            [self.delegate rangeSelectEnableForLineGraph:self]) {
            NSRange selectedRange = NSMakeRange(_leftSelectedIdx, _rightSelectedIdx - _leftSelectedIdx);
            [self.delegate lineGraph:self didSelectedWithIndexRange:selectedRange];
        }
    }
}


- (void)tapHandlerForPanView:(UIGestureRecognizer *)recognizer {
    if (_isGraphSelected) {
        [self reloadGraphSelectedState:NO];
    }
}

#pragma mark - Graph Calculations

//- (MTHCircle *)closestDotFromtouchInputLine:(UIView *)touchInputLine {
//    currentlyCloser = CGFLOAT_MAX;
//    for (MTHCircle *point in self.subviews) {
//        if (point.tag >= DotFirstTag100 && point.tag < DotLastTag1000 && [point isMemberOfClass:[MTHCircle class]]) {
//            if (self.alwaysDisplayDots == NO && self.displayDotsOnly == NO) {
//                point.alpha = 0;
//            }
//            if (pow(((point.center.x) - touchInputLine.center.x), 2) < currentlyCloser) {
//                currentlyCloser = pow(((point.center.x) - touchInputLine.center.x), 2);
//                closestDot = point;
//            }
//        }
//    }
//    return closestDot;
//}

- (CGFloat)getMaximumValue {
    if ([self.delegate respondsToSelector:@selector(maxValueForLineGraph:)]) {
        return [self.delegate maxValueForLineGraph:self];
    } else {
        CGFloat dotValue;
        CGFloat maxValue = -FLT_MAX;

        @autoreleasepool {
            for (int i = 0; i < numberOfPoints; i++) {
                if ([self.dataSource respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                    dotValue = [self.dataSource lineGraph:self valueForPointAtIndex:i];

                } else if ([self.delegate respondsToSelector:@selector(valueForIndex:)]) {
                    [self printDeprecationWarningForOldMethod:@"valueForIndex:" andReplacementMethod:@"lineGraph:valueForPointAtIndex:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    dotValue = [self.delegate valueForIndex:i];
#pragma clang diagnostic pop

                } else if ([self.delegate respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                    [self printDeprecationAndUnavailableWarningForOldMethod:@"lineGraph:valueForPointAtIndex:"];
                    NSException *exception = [NSException exceptionWithName:@"Implementing Unavailable Delegate Method" reason:@"lineGraph:valueForPointAtIndex: is no longer available on the delegate. It must be implemented on the data source." userInfo:nil];
                    [exception raise];

                } else {
                    dotValue = 0;
                }
                if (dotValue == MTHNullGraphValue) {
                    continue;
                }

                if (dotValue > maxValue) {
                    maxValue = dotValue;
                }
            }
        }
        return maxValue;
    }
}

- (CGFloat)getMinimumValue {
    if ([self.delegate respondsToSelector:@selector(minValueForLineGraph:)]) {
        return [self.delegate minValueForLineGraph:self];
    } else {
        CGFloat dotValue;
        CGFloat minValue = INFINITY;

        @autoreleasepool {
            for (int i = 0; i < numberOfPoints; i++) {
                if ([self.dataSource respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                    dotValue = [self.dataSource lineGraph:self valueForPointAtIndex:i];

                } else if ([self.delegate respondsToSelector:@selector(valueForIndex:)]) {
                    [self printDeprecationWarningForOldMethod:@"valueForIndex:" andReplacementMethod:@"lineGraph:valueForPointAtIndex:"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    dotValue = [self.delegate valueForIndex:i];
#pragma clang diagnostic pop

                } else if ([self.delegate respondsToSelector:@selector(lineGraph:valueForPointAtIndex:)]) {
                    [self printDeprecationAndUnavailableWarningForOldMethod:@"lineGraph:valueForPointAtIndex:"];
                    NSException *exception = [NSException exceptionWithName:@"Implementing Unavailable Delegate Method" reason:@"lineGraph:valueForPointAtIndex: is no longer available on the delegate. It must be implemented on the data source." userInfo:nil];
                    [exception raise];

                } else
                    dotValue = 0;

                if (dotValue == MTHNullGraphValue) {
                    continue;
                }
                if (dotValue < minValue) {
                    minValue = dotValue;
                }
            }
        }
        return minValue;
    }
}

- (CGFloat)yPositionForDotValue:(CGFloat)dotValue {
    if (dotValue == MTHNullGraphValue) {
        return MTHNullGraphValue;
    }

    CGFloat positionOnYAxis; // The position on the Y-axis of the point currently being created.
    CGFloat padding = self.frame.size.height / 2;
    if (padding > 90.0) {
        padding = 90.0;
    }

    if ([self.delegate respondsToSelector:@selector(staticPaddingForLineGraph:)])
        padding = [self.delegate staticPaddingForLineGraph:self];

    if (self.enableXAxisLabel) {
        if ([self.dataSource respondsToSelector:@selector(lineGraph:labelOnXAxisForIndex:)] || [self.dataSource respondsToSelector:@selector(labelOnXAxisForIndex:)]) {
            if ([xAxisLabels count] > 0) {
                UILabel *label = [xAxisLabels objectAtIndex:0];
                self.XAxisLabelYOffset = label.frame.size.height + self.widthLine;
            }
        }
    }

    if (self.minValue == self.maxValue && self.autoScaleYAxis == YES)
        positionOnYAxis = self.frame.size.height / 2;
    else if (self.autoScaleYAxis == YES)
        positionOnYAxis = ((self.frame.size.height - padding / 2) - ((dotValue - self.minValue) / ((self.maxValue - self.minValue) / (self.frame.size.height - padding)))) + self.XAxisLabelYOffset / 2;
    else
        positionOnYAxis = ((self.frame.size.height) - dotValue);

    positionOnYAxis -= self.XAxisLabelYOffset;

    return positionOnYAxis;
}

#pragma mark - Customization Methods

- (void)setColorTouchInputLine:(UIColor *)colorTouchInputLine {
    _colorTouchInputLine = colorTouchInputLine;
}

#pragma mark - Other Methods

- (void)printDeprecationAndUnavailableWarningForOldMethod:(NSString *)oldMethod {
    NSLog(@"[MTHSimpleLineGraph] UNAVAILABLE, DEPRECATION ERROR. The delegate method, %@, is both deprecated and unavailable. It is now a data source method. You must implement this method from MTHSimpleLineGraphDataSource. Update your delegate method as soon as possible. One of two things will now happen: A) an exception will be thrown, or B) the graph will not load.", oldMethod);
}

- (void)printDeprecationWarningForOldMethod:(NSString *)oldMethod andReplacementMethod:(NSString *)replacementMethod {
    NSLog(@"[MTHSimpleLineGraph] DEPRECATION WARNING. The delegate method, %@, is deprecated and will become unavailable in a future version. Use %@ instead. Update your delegate method as soon as possible. An exception will be thrown in a future version.", oldMethod, replacementMethod);
}

#pragma mark - UI

- (void)addTouchInputLine {
    if (_touchInputLine == nil) {
        _touchInputLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.widthTouchInputLine, self.frame.size.height)];
        _touchInputLine.backgroundColor = self.colorTouchInputLine;
        _touchInputLine.alpha = 0;
        [self addSubview:_touchInputLine];
    }
}

- (void)addLeftTouchLine {
    if (_leftTouchLine == nil) {
        CGRect frame = CGRectMake(0, 0, self.widthTouchInputLine, self.frame.size.height);
        _leftTouchLine = [[MTHTouchLineView alloc] initWithFrame:frame labelTopOffset:10];
        _leftTouchLine.backgroundColor = kTouchLineColor;
        _leftTouchLine.alpha = 0;
        _leftTouchLine.numLabel.textColor = kTouchLineColor;
        [self.panView addSubview:_leftTouchLine];
    }
}

- (void)addRightTouchLine {
    if (_rightTouchLine == nil) {
        CGRect frame = CGRectMake(0, 0, self.widthTouchInputLine, self.frame.size.height);
        _rightTouchLine = [[MTHTouchLineView alloc] initWithFrame:frame labelTopOffset:30];
        _rightTouchLine.backgroundColor = kTouchLineColor;
        _rightTouchLine.alpha = 0;
        _rightTouchLine.numLabel.textColor = kTouchLineColor;
        [self.panView addSubview:_rightTouchLine];
    }
}

- (void)addPanView {
    if (_panView == nil) {
        CGRect frame = [self drawableGraphArea];
        self.panView = [[UIView alloc] initWithFrame:frame];
        self.panView.tag = PanViewTag4000;
        [self.viewForBaselineLayout addSubview:self.panView];

        //seletec shap
        self.selectedShapeLayer = [CAShapeLayer layer];
        _selectedShapeLayer.frame = _panView.bounds;
        _selectedShapeLayer.hidden = YES;
        UIColor *alphaColor = [UIColor colorWithWhite:1 alpha:0.5];
        _selectedShapeLayer.fillColor = alphaColor.CGColor;
        [_panView.layer addSublayer:_selectedShapeLayer];

        //tap gesture
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapHandlerForPanView:)];
        [_panView addGestureRecognizer:tap];
    }
//pan view 不必每次重新绘
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 9, *)) {
        [self.viewForLastBaselineLayout bringSubviewToFront:_panView];
    }
#endif
}

// controller
static const CGFloat rangePickViewFullWidth = 40; // 完整区间拨片视图的宽，高
static const CGFloat rangePickViewFullHeight = 32;
static const CGFloat rangePickViewWidth = 18; // 拨片视图绘制的宽、高
static const CGFloat rangePickViewHeight = 20;

- (void)drawLineController {
    // 增大视图区域
    CGRect frame = CGRectMake(100, 0, rangePickViewFullWidth, rangePickViewFullHeight);
    [self drawLineController:frame index:0];
    frame = CGRectMake(200, 0, rangePickViewFullWidth, rangePickViewFullHeight);
    [self drawLineController:frame index:1];
}

//index 0 for left, 1 for right
- (void)drawLineController:(CGRect)frame index:(NSInteger)index {
    //
    if (![self delegateValidForSEL:@selector(rangeSelectEnableForLineGraph:)] || ![self.delegate rangeSelectEnableForLineGraph:self]) {
        return;
    }

    UIView *rangePickView = [[UIView alloc] initWithFrame:frame];
    rangePickView.tag = kTagBaseForLineController + index;
    [self.backgroundXAxis addSubview:rangePickView];

    // triangle
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    CGFloat shapeWidth = rangePickViewWidth, shapeHeight = rangePickViewHeight;
    CGRect rangePickShapeFrame = rangePickView.bounds;
    CGRect rangePickShapePath = CGRectMake((frame.size.width - shapeWidth) / 2.f, 0, shapeWidth, shapeHeight);
    shapeLayer.frame = rangePickShapeFrame;
    shapeLayer.path = [[self trianglePathWithRect:rangePickShapePath] CGPath];
    shapeLayer.fillColor = (index == 0) ? _leftTouchLine.backgroundColor.CGColor : _rightTouchLine.backgroundColor.CGColor;
    [rangePickView.layer addSublayer:shapeLayer];

    //gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapHandlerForLine:)];
    [rangePickView addGestureRecognizer:tap];

    SEL gestureSel = NULL;
    if (index == 0) {
        // _leftTouchLine.center = v.center
        _leftTouchLine.frame = CGRectMake(rangePickView.frame.origin.x + rangePickView.frame.size.width / 2.0, _leftTouchLine.frame.origin.y, _leftTouchLine.frame.size.width, _leftTouchLine.frame.size.height);
    } else {
        _rightTouchLine.frame = CGRectMake(rangePickView.frame.origin.x + rangePickView.frame.size.width / 2.0, _rightTouchLine.frame.origin.y, _rightTouchLine.frame.size.width, _rightTouchLine.frame.size.height);
    }

    gestureSel = @selector(panHandlerForLine:);
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:gestureSel];
    pan.delegate = self;
    [rangePickView addGestureRecognizer:pan];
}

- (void)addBackgroundXAxis {
    if (_backgroundXAxis) { //这个也不用每次重绘啊
        [self bringSubviewToFront:_backgroundXAxis];
        return;
    }
    self.backgroundXAxis = [[UIView alloc] initWithFrame:[self drawableXAxisArea]];
    self.backgroundXAxis.tag = BackgroundXAxisTag2200;
    if (self.colorBackgroundXaxis == nil)
        self.backgroundXAxis.backgroundColor = self.colorBottom;
    else
        self.backgroundXAxis.backgroundColor = self.colorBackgroundXaxis;
    self.backgroundXAxis.alpha = self.alphaBackgroundXaxis;
    [self addSubview:self.backgroundXAxis];
    [self drawLineController];
}

#pragma mark - Privite

// 可以考虑抽出去
- (UIBezierPath *)trianglePathWithRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint top = CGPointMake(rect.origin.x + rect.size.width / 2.f, rect.origin.y);
    CGPoint right1 = CGPointMake((ceil)(rect.origin.x + rect.size.width * 3.f / 4.f), (ceil)(rect.origin.y + rect.size.height / 3.f));
    CGPoint right2 = CGPointMake((ceil)(rect.origin.x + rect.size.width * 3.f / 4.f), (ceil)(rect.origin.y + rect.size.height));
    CGPoint left2 = CGPointMake((ceil)(rect.origin.x + rect.size.width * 1.f / 4.f), (ceil)(rect.origin.y + rect.size.height));
    CGPoint left1 = CGPointMake((ceil)(rect.origin.x + rect.size.width * 1.f / 4.f), (ceil)(rect.origin.y + rect.size.height / 3.f));

    [path moveToPoint:top];
    [path addLineToPoint:right1];
    [path addLineToPoint:right2];
    [path addLineToPoint:left2];
    [path addLineToPoint:left1];
    [path addLineToPoint:top];

    [path closePath];

    return path;
}

// 可以考虑抽出去 left,right,rect外面传进来
- (UIBezierPath *)selectedBezierPath {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat height = _panView.frame.size.height;
    CGFloat width = _panView.frame.size.width;

    CGPoint left = _leftTouchLine.frame.origin;
    CGPoint right = _rightTouchLine.frame.origin;
    if (_leftTouchLine.frame.origin.x > _rightTouchLine.frame.origin.x) {
        left = _rightTouchLine.frame.origin;
        right = _leftTouchLine.frame.origin;
    }

    CGPoint pl2 = CGPointMake(left.x, height);
    CGPoint pr2 = CGPointMake(right.x, height);

    // _pan view 四个顶点，因为在pan view上，所以0，0开始
    CGPoint p00 = CGPointMake(0, 0);
    CGPoint p01 = CGPointMake(width, 0);
    CGPoint p02 = CGPointMake(width, height);
    CGPoint p03 = CGPointMake(0, height);

    [path moveToPoint:p00];

    [path addLineToPoint:left];
    [path addLineToPoint:pl2];
    [path addLineToPoint:pr2];
    [path addLineToPoint:right];

    [path addLineToPoint:p01];
    [path addLineToPoint:p02];
    [path addLineToPoint:p03];
    [path addLineToPoint:p00];

    [path closePath];

    return path;
}

- (void)reloadGraphSelectedState:(BOOL)isSelected {
    _isGraphSelected = isSelected;
    _selectedShapeLayer.hidden = !_isGraphSelected;
    _leftTouchLine.alpha = _rightTouchLine.alpha = _isGraphSelected ? 1.0 : 0.f;
    if (_isGraphSelected) {
        _selectedShapeLayer.path = [self selectedBezierPath].CGPath;
    } else {
        if ([self delegateValidForSEL:@selector(rangeSelectEnableForLineGraph:)] &&
            [self delegateValidForSEL:@selector(lineGraph:didSelectedWithIndexRange:)] &&
            [self.delegate rangeSelectEnableForLineGraph:self]) {
            NSRange selectedRange = NSMakeRange(0, numberOfPoints);
            [self.delegate lineGraph:self didSelectedWithIndexRange:selectedRange];
        }
    }
}

- (CGFloat)pointXInScope:(CGFloat)px {
    if (px <= 0) {
        return 0;
    }
    if (px >= _panView.frame.size.width) {
        return _panView.frame.size.width - _widthTouchInputLine;
    }
    return px;
}

- (NSInteger)nearestIndexForPointx:(CGFloat)pointx {
    //四舍五入
    NSDecimalNumberHandler *roundingBehavior = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundPlain scale:0 raiseOnExactness:NO raiseOnOverflow:NO raiseOnUnderflow:NO raiseOnDivideByZero:NO];
    NSDecimalNumber *dn = [NSDecimalNumber decimalNumberWithString:@(pointx).stringValue];
    NSDecimalNumber *rs = [dn decimalNumberByRoundingAccordingToBehavior:roundingBehavior];

    if ([rs integerValue] <= 0) {
        return 0;
    }
    if ([rs integerValue] >= numberOfPoints) {
        return numberOfPoints - 1;
    }
    return [rs integerValue];
}

- (BOOL)delegateValidForSEL:(SEL)sel {
    if ([self.delegate respondsToSelector:sel] && self.delegate) {
        return YES;
    }
    return NO;
}


@end


@implementation MTHTouchLineView

- (instancetype)initWithFrame:(CGRect)frame labelTopOffset:(CGFloat)topOffset {
    if (self = [super initWithFrame:frame]) {
        //
        CGRect rect = CGRectMake(3, topOffset, 100, 15);
        self.numLabel = [[UILabel alloc] initWithFrame:rect];
        self.numLabel.font = [UIFont systemFontOfSize:13];
        [self addSubview:_numLabel];
        self.clipsToBounds = NO;
    }
    return self;
}

- (void)setValueForNumberLabel:(NSNumber *)value {
    _numLabel.text = [NSString stringWithFormat:@"%.2f", value.floatValue];
    // 这边可以计算lable的宽度，实时调整。
}

- (void)reloadNumLabelFrameWithMaxWidth:(CGFloat)maxWidth {
    CGRect lRect = [self.numLabel.text boundingRectWithSize:CGSizeMake(100, 15) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName : self.numLabel.font} context:nil];

    // 减少frame的变化，减少CPU的消耗
    if (self.numLabel.frame.origin.x < 0) {
        //label在左边
        if (self.frame.origin.x < lRect.size.width) {
            //change to right
            [UIView animateWithDuration:0.1
                             animations:^{
                                 self.numLabel.frame = CGRectMake(3, self.numLabel.frame.origin.y, self.numLabel.frame.size.width, self.numLabel.frame.size.height);
                             }];
        }
    } else {
        if (self.frame.origin.x + lRect.size.width > maxWidth) {
            //change to left
            [UIView animateWithDuration:0.1
                             animations:^{
                                 self.numLabel.frame = CGRectMake(-lRect.size.width - 3, self.numLabel.frame.origin.y, self.numLabel.frame.size.width, self.numLabel.frame.size.height);
                             }];
        }
    }
}

@end
