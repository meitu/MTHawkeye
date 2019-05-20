//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 28/07/2017
// Created by: EuanC
//


#import "MTHNetworkStat.h"


@interface MTHawkeyeNetworkExponentialGeometricAverage : NSObject

@property (nonatomic, assign) CGFloat decayConstant;
@property (nonatomic, assign) NSInteger cutover;

@property (nonatomic, assign) double value;
@property (nonatomic, assign) NSInteger count;

- (instancetype)initWithDecayConstant:(CGFloat)decayConstant;

@end

@implementation MTHawkeyeNetworkExponentialGeometricAverage

- (instancetype)initWithDecayConstant:(CGFloat)decayConstant {
    if ((self = [super init])) {
        _decayConstant = decayConstant;
        _cutover = (decayConstant == 0.f) ? NSIntegerMax : ceil(1 / decayConstant);
        _value = -1.f;
    }
    return self;
}

- (void)addMeasurement:(double)measurement {
    double keepConstant = 1 - self.decayConstant;
    if (self.count > self.cutover) {
        self.value = exp(keepConstant * log(self.value) + self.decayConstant * log(measurement));
    } else if (self.count > 0) {
        double retained = keepConstant * self.count / (self.count + 1.f);
        double newcomer = 1.0 - retained;
        self.value = exp(retained * log(self.value) + newcomer * log(measurement));
    } else {
        self.value = measurement;
    }
    self.count++;
}

- (CGFloat)average {
    return self.value;
}

- (void)reset {
    self.value = -1.f;
    self.count = 0;
}

@end


// MARK: -

//
// default values for determining quality of data connection.
// bandwidth numbers are in Kilobits per second (kbps).
//
NSInteger gMTHNetworkStatDefaultPoorBandwidth = 150;
NSInteger gMTHNetworkStatDefaultModerateBandwidth = 550;
NSInteger gMTHNetworkStatDefaultGoodBandwidth = 2000;

static const CGFloat kDefaultHysteresisPercent = 20;
static const CGFloat kHysteresisTopMultiplier = 100.f / (100.f - kDefaultHysteresisPercent);
static const CGFloat kHysteresisBottomMultiplier = (100.f - kDefaultHysteresisPercent) / 100.f;

// factor used to calculate the current bandwidth
// depending upon the previous calculated value for bandwidth.
// the smaller this value is, the less responsive to new samples the moving average becomes.
CGFloat gMTHNetworkStatDefaultDecayConstant = 0.1; // facebook default: 0.05

// the lower bound for measured bandwidth in bits/ms.
// reading lower than this are treated as effectively zero (therefore ignored).
CGFloat gMTHNetworkStatBandwidthLowerBound = 0.1; // facebook default: 20
CGFloat gMTHNetworkStatBytesLowerBound = 20;      // ignore 20 bytes

NSInteger gMTHNetworkStatDefaultSamplesToQualityChange = 3;

#define kBytesToBits 8

@interface MTHNetworkStat ()

@property (nonatomic, strong) MTHawkeyeNetworkExponentialGeometricAverage *downloadBandwidth;
@property (nonatomic, assign) BOOL initiateStateChange;
@property (atomic, assign) MTHawkeyeNetworkConnectionQuality connQuality;
@property (nonatomic, assign) MTHawkeyeNetworkConnectionQuality nextBandwidthConnectionQuality;

@property (nonatomic, assign) NSInteger sampleCounter;

@end


@implementation MTHNetworkStat

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _downloadBandwidth = [[MTHawkeyeNetworkExponentialGeometricAverage alloc] initWithDecayConstant:gMTHNetworkStatDefaultDecayConstant];
        _initiateStateChange = NO;
        _connQuality = MTHawkeyeNetworkConnectionQualityUnknown;
        _nextBandwidthConnectionQuality = MTHawkeyeNetworkConnectionQualityUnknown;
    }
    return self;
}

- (void)addBandwidthWithBytes:(int64_t)bytes duration:(NSTimeInterval)timeInMs {
    // ignore garbage values
    if (timeInMs < DBL_EPSILON || bytes < gMTHNetworkStatBytesLowerBound || bytes * 1.0 / timeInMs * kBytesToBits < gMTHNetworkStatBandwidthLowerBound) {
        return;
    }

    double bandwidth = bytes * 1.0 / timeInMs * kBytesToBits;
    [self.downloadBandwidth addMeasurement:bandwidth];

    if (self.initiateStateChange) {
        self.sampleCounter += 1;
        if ([self currentBandwidthConnectionQuality] != self.nextBandwidthConnectionQuality) {
            self.initiateStateChange = NO;
            self.sampleCounter = 1;
        }
        if (self.sampleCounter >= gMTHNetworkStatDefaultSamplesToQualityChange && [self significantlyOutsideCurrentBand]) {
            self.initiateStateChange = NO;
            self.sampleCounter = 1;
            self.connQuality = self.nextBandwidthConnectionQuality;
        }
        return;
    }

    if (self.connQuality != [self currentBandwidthConnectionQuality]) {
        self.initiateStateChange = YES;
        self.nextBandwidthConnectionQuality = [self currentBandwidthConnectionQuality];
    }
}

- (void)reset {
    if (self.downloadBandwidth) {
        [self.downloadBandwidth reset];
    }
    self.connQuality = MTHawkeyeNetworkConnectionQualityUnknown;
}

- (BOOL)significantlyOutsideCurrentBand {
    if (self.downloadBandwidth == nil) {
        return NO;
    }

    MTHawkeyeNetworkConnectionQuality currentQuality = self.connQuality;
    CGFloat bottomOfBand;
    CGFloat topOfBand;
    switch (currentQuality) {
        case MTHawkeyeNetworkConnectionQualityPoor:
            bottomOfBand = 0;
            topOfBand = gMTHNetworkStatDefaultPoorBandwidth;
            break;
        case MTHawkeyeNetworkConnectionQualityModerate:
            bottomOfBand = gMTHNetworkStatDefaultPoorBandwidth;
            topOfBand = gMTHNetworkStatDefaultModerateBandwidth;
            break;
        case MTHawkeyeNetworkConnectionQualityGood:
            bottomOfBand = gMTHNetworkStatDefaultModerateBandwidth;
            topOfBand = gMTHNetworkStatDefaultGoodBandwidth;
            break;
        case MTHawkeyeNetworkConnectionQualityExcellent:
            bottomOfBand = gMTHNetworkStatDefaultGoodBandwidth;
            topOfBand = CGFLOAT_MAX;
            break;
        default: // if current quality is Unknown, then changing is always valid.
            return YES;
    }

    CGFloat average = [self.downloadBandwidth average];
    if (average > topOfBand) {
        if (average > topOfBand * kHysteresisTopMultiplier) {
            return YES;
        }
    } else if (average < bottomOfBand * kHysteresisBottomMultiplier) {
        return YES;
    }
    return NO;
}

- (MTHawkeyeNetworkConnectionQuality)currentBandwidthConnectionQuality {
    if (self.downloadBandwidth == nil) {
        return MTHawkeyeNetworkConnectionQualityUnknown;
    }
    return [self mapBandwidthQuality:[self.downloadBandwidth average]];
}

- (MTHawkeyeNetworkConnectionQuality)mapBandwidthQuality:(CGFloat)average {
    if (average < 0) {
        return MTHawkeyeNetworkConnectionQualityUnknown;
    }
    if (average < gMTHNetworkStatDefaultPoorBandwidth) {
        return MTHawkeyeNetworkConnectionQualityPoor;
    }
    if (average < gMTHNetworkStatDefaultModerateBandwidth) {
        return MTHawkeyeNetworkConnectionQualityModerate;
    }
    if (average < gMTHNetworkStatDefaultGoodBandwidth) {
        return MTHawkeyeNetworkConnectionQualityGood;
    }
    return MTHawkeyeNetworkConnectionQualityExcellent;
}

@end
