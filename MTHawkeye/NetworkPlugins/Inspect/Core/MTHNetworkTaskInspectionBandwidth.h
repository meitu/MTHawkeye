//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTaskInspection;

extern NSString *kkMTHNetworkTaskAdviceKeyDuplicatedRequestIndexList;

/**
 Bandwidth Inpsection 主要用于侦测带宽相关的优化项
 */
@interface MTHNetworkTaskInspectionBandwidth : NSObject

/**
 Detecting if response body is compressed

 建议检查 HTTP Request Header 看是否已正确配置 Accept-Encoding
 然后检查后端是否配置正常，请求正常的话服务端返回头应包含预期的 Content-Type
 */
+ (MTHNetworkTaskInspection *)responseContentEncodingInspection;

/**
 Detecting duplicate network transactions

 建议将一些网络请求直接缓存到本地，减少后续的请求次数；
 如果是需要及时刷新的数据，建议使用 HTTP Cache-Control 来减少数据未更新时返回数据包的大小
 */
+ (MTHNetworkTaskInspection *)duplicateRequestInspection;

/**
 Detecting image size and quality for optimized web requests (not available yet)

 建议在不同网络环境下使用不同质量的图片
 建议使用压缩比更高的图片格式 (如 webp)
 */
+ (MTHNetworkTaskInspection *)responseImagePayloadInspection;

@end

NS_ASSUME_NONNULL_END
