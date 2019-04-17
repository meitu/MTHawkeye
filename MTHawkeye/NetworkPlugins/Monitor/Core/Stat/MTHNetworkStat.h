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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


extern NSInteger gMTHNetworkStatDefaultPoorBandwidth;     // default 150
extern NSInteger gMTHNetworkStatDefaultModerateBandwidth; // default 550
extern NSInteger gMTHNetworkStatDefaultGoodBandwidth;     // default 2000

// factor used to calculate the current bandwidth
// depending upon the previous calculated value for bandwidth.
// the smaller this value is, the less responsive to new samples the moving average becomes.
extern CGFloat gMTHNetworkStatDefaultDecayConstant; // default: 0.1, facebook default: 0.05

// the lower bound for measured bandwidth in bits/ms.
// reading lower than this are treated as effectively zero (therefore ignored).
extern CGFloat gMTHNetworkStatBandwidthLowerBound; // default: 0.1, facebook default: 20
extern CGFloat gMTHNetworkStatBytesLowerBound;     // default: 20

extern NSInteger gMTHNetworkStatDefaultSamplesToQualityChange; // default 3

/**
 目前暂缺乏可用的 API 测量实际的下行带宽
 此仅为网络质量的大概估算，实际应用过程中，如果为 Poor，请尽量减少网络请求的数量和请求包大小
 Moderate 下，能满足普通应用的一般频率网络请求需求
 */
typedef NS_ENUM(NSInteger, MTHawkeyeNetworkConnectionQuality) {
    MTHawkeyeNetworkConnectionQualityUnknown = 0,   // Placeholder for unknown bandwidth.
    MTHawkeyeNetworkConnectionQualityPoor = 1,      // Bandwidth under 150 kbps.
    MTHawkeyeNetworkConnectionQualityModerate = 2,  // Bandwidth between 150 and 550 kbps.
    MTHawkeyeNetworkConnectionQualityGood = 3,      // Bandwidth between 550 and 2000 kbps.
    MTHawkeyeNetworkConnectionQualityExcellent = 4, // EXCELLENT - Bandwidth over 2000 kbps.
};

@interface MTHNetworkStat : NSObject

@property (atomic, assign, readonly) MTHawkeyeNetworkConnectionQuality connQuality;

+ (instancetype)shared;

- (void)addBandwidthWithBytes:(int64_t)bytes duration:(NSTimeInterval)timeInMs;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
