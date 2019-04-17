//
//  MTHLine.m
//  SimpleLineGraph
//
//  Created by Bobo on 12/27/13. Updated by Sam Spencer on 1/11/14.
//  Copyright (c) 2013 Boris Emorine. All rights reserved.
//  Copyright (c) 2014 Sam Spencer.
//

#import "MTHLine.h"
#import "MTHSimpleLineGraphView.h"

#if CGFLOAT_IS_DOUBLE
#define CGFloatValue doubleValue
#else
#define CGFloatValue floatValue
#endif


@interface MTHLine ()

@property (nonatomic, strong) NSMutableArray *points;
@property (nonatomic, strong) UIBezierPath *path;

@end

@implementation MTHLine

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        _enableLeftReferenceFrameLine = YES;
        _enableBottomReferenceFrameLine = YES;
        _interpolateNullValues = YES;
    }
    return self;
}

+ (Class)layerClass {
    return [CAShapeLayer class];
}

- (UIBezierPath *)path {
    if (!_path) {
        _path = [[UIBezierPath alloc] init];
        CAShapeLayer *shapeLayer = (CAShapeLayer *)self.layer;
        shapeLayer.strokeColor = [UIColor lightGrayColor].CGColor; // self.topColor.CGColor;
        shapeLayer.fillColor = [UIColor lightGrayColor].CGColor;   //self.topColor.CGColor;
        shapeLayer.lineJoin = kCALineJoinRound;
        shapeLayer.lineCap = kCALineCapRound;
        shapeLayer.lineWidth = self.lineWidth;
    }
    return _path;
}

- (void)setArrayOfValues:(NSArray *)arrayOfValues {
    _arrayOfValues = arrayOfValues;

    self.points = [NSMutableArray arrayWithCapacity:self.arrayOfPoints.count];
    CGFloat xIndexScale = self.frame.size.width / ([self.arrayOfPoints count] - 1);
    @autoreleasepool {
        for (int i = 0; i < self.arrayOfPoints.count; i++) {
            CGPoint value = CGPointMake(xIndexScale * i, [self.arrayOfPoints[i] CGFloatValue]);
            if (value.y != MTHNullGraphValue || !self.interpolateNullValues) {
                [self.points addObject:[NSValue valueWithCGPoint:value]];
            }
        }
    }
    [self configurePathWithTopPoints:self.topPointsArray];
}

- (NSArray *)topPointsArray {
    CGPoint topPointZero = CGPointMake(0, self.frame.size.height);
    CGPoint topPointFull = CGPointMake(self.frame.size.width, self.frame.size.height);
    NSMutableArray *topPoints = [NSMutableArray arrayWithArray:self.points];
    [topPoints insertObject:[NSValue valueWithCGPoint:topPointZero] atIndex:0];
    [topPoints addObject:[NSValue valueWithCGPoint:topPointFull]];
    return topPoints;
}

- (NSArray *)bottomPointsArray {
    CGPoint bottomPointZero = CGPointMake(0, self.frame.size.height);
    CGPoint bottomPointFull = CGPointMake(self.frame.size.width, self.frame.size.height);
    NSMutableArray *bottomPoints = [NSMutableArray arrayWithArray:self.points];
    [bottomPoints insertObject:[NSValue valueWithCGPoint:bottomPointZero] atIndex:0];
    [bottomPoints addObject:[NSValue valueWithCGPoint:bottomPointFull]];
    return bottomPoints;
}

- (void)configurePathWithTopPoints:(NSArray<NSValue *> *)topPoints {
    [self.path removeAllPoints];

    CGPoint beginPT = [[topPoints firstObject] CGPointValue];
    [self.path moveToPoint:beginPT];

    @autoreleasepool {
        for (int i = 1; i < topPoints.count; ++i) {
            CGPoint point = [topPoints[i] CGPointValue];
            [self.path addLineToPoint:point];
        }
    }

    ((CAShapeLayer *)self.layer).path = self.path.CGPath;
}

+ (UIBezierPath *)linesToPoints:(NSArray *)points {
    UIBezierPath *path = [UIBezierPath bezierPath];
    NSValue *value = points[0];
    CGPoint p1 = [value CGPointValue];
    [path moveToPoint:p1];

    for (NSUInteger i = 1; i < points.count; i++) {
        value = points[i];
        CGPoint p2 = [value CGPointValue];
        [path addLineToPoint:p2];
    }
    return path;
}

+ (UIBezierPath *)quadCurvedPathWithPoints:(NSArray *)points {
    UIBezierPath *path = [UIBezierPath bezierPath];

    NSValue *value = points[0];
    CGPoint p1 = [value CGPointValue];
    [path moveToPoint:p1];

    if (points.count == 2) {
        value = points[1];
        CGPoint p2 = [value CGPointValue];
        [path addLineToPoint:p2];
        return path;
    }

    for (NSUInteger i = 1; i < points.count; i++) {
        value = points[i];
        CGPoint p2 = [value CGPointValue];

        CGPoint midPoint = midPointForPoints(p1, p2);
        [path addQuadCurveToPoint:midPoint controlPoint:controlPointForPoints(midPoint, p1)];
        [path addQuadCurveToPoint:p2 controlPoint:controlPointForPoints(midPoint, p2)];

        p1 = p2;
    }
    return path;
}

static CGPoint midPointForPoints(CGPoint p1, CGPoint p2) {
    return CGPointMake((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
}

static CGPoint controlPointForPoints(CGPoint p1, CGPoint p2) {
    CGPoint controlPoint = midPointForPoints(p1, p2);
    CGFloat diffY = fabs(p2.y - controlPoint.y);

    if (p1.y < p2.y)
        controlPoint.y += diffY;
    else if (p1.y > p2.y)
        controlPoint.y -= diffY;

    return controlPoint;
}

- (void)animateForLayer:(CAShapeLayer *)shapeLayer withAnimationType:(MTHLineAnimation)animationType isAnimatingReferenceLine:(BOOL)shouldHalfOpacity {
    if (animationType == MTHLineAnimationNone)
        return;
    else if (animationType == MTHLineAnimationFade) {
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pathAnimation.duration = self.animationTime;
        pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
        if (shouldHalfOpacity == YES)
            pathAnimation.toValue = [NSNumber numberWithFloat:self.lineAlpha == 0 ? 0.1 : self.lineAlpha / 2];
        else
            pathAnimation.toValue = [NSNumber numberWithFloat:self.lineAlpha];
        [shapeLayer addAnimation:pathAnimation forKey:@"opacity"];

        return;
    } else if (animationType == MTHLineAnimationExpand) {
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
        pathAnimation.duration = self.animationTime;
        pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
        pathAnimation.toValue = [NSNumber numberWithFloat:shapeLayer.lineWidth];
        [shapeLayer addAnimation:pathAnimation forKey:@"lineWidth"];

        return;
    } else {
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        pathAnimation.duration = self.animationTime;
        pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
        pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
        [shapeLayer addAnimation:pathAnimation forKey:@"strokeEnd"];

        return;
    }
}

- (CALayer *)backgroundGradientLayerForLayer:(CAShapeLayer *)shapeLayer {
    UIGraphicsBeginImageContext(self.bounds.size);
    CGContextRef imageCtx = UIGraphicsGetCurrentContext();
    CGPoint start, end;
    if (self.lineGradientDirection == MTHLineGradientDirectionHorizontal) {
        start = CGPointMake(0, CGRectGetMidY(shapeLayer.bounds));
        end = CGPointMake(CGRectGetMaxX(shapeLayer.bounds), CGRectGetMidY(shapeLayer.bounds));
    } else {
        start = CGPointMake(CGRectGetMidX(shapeLayer.bounds), 0);
        end = CGPointMake(CGRectGetMidX(shapeLayer.bounds), CGRectGetMaxY(shapeLayer.bounds));
    }

    CGContextDrawLinearGradient(imageCtx, self.lineGradient, start, end, 0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CALayer *gradientLayer = [CALayer layer];
    gradientLayer.frame = self.bounds;
    gradientLayer.contents = (id)image.CGImage;
    gradientLayer.mask = shapeLayer;
    return gradientLayer;
}

@end
