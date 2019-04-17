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

/**
 Latency Inspection 主要用于首包时间优化相关项

 - 启动 20s 之后的网络请求，包含 dns 时长占比超过 1/3 的请求 (域名收编)
 - 重定向请求最后一阶段外的时间 t 占总时长 1/2 以上
 - 重定向请求第一阶段之后包含了 dns/conn 时间
 - http keep-alive 关闭
 - 并发的网络请求，包含多个 host，且出现并发的 tcp 握手  (0.5d)
 - 包含 tcp 握手的连接，往前十秒内有可复用的同类 host (0.5d)
 - 总的请求使用的域名数超过5个，建议收敛域名

 */
@interface MTHNetworkTaskInspectionLatency : NSObject

/**
 Detecting DNS connection time
 
 策略: 总体时长 > 300ms & dns 时间占比 > 1/3

 建议:
 使用 MTFastDNS 或类似方案减少 DNS 耗时
 如果是链路复用问题，建议收敛域名
 如果未使用 HTTP 2.0，建议升级到 HTTP 2.0 提升连接复用率

 */
+ (MTHNetworkTaskInspection *)dnsCostInspection;

/**
 Detecting HTTP too much extra time cost cause of redirects

 策略1: 总体时长 > 300ms & 重定向时间最后一段之外的时间占时长 > 1/2
 策略2: 总体时长 > 300ms & 重定向第一段之后包含了 dns/tcp connection 耗时

 建议:
 如果重定向包含了不同的域名，建议收敛为同一域名，减少可能发生的 dns, tcp connection 耗时
 尽量减少不必要的 HTTP 重定向，移动网络环境下 HTTP 重定向会大幅提高请求延时。
 */
+ (MTHNetworkTaskInspection *)redirectRequestInspection;

/**
 Detecting HTTP keep-alive not used

 建议无特殊原因，不要关闭 keep-alive

 */
+ (MTHNetworkTaskInspection *)httpKeepAliveInspection;

/**
 Detecting use too many second-level domains

 策略: 主域名下使用了过多的二级域名 > 3

 建议:
 使用的域名数过多，建议收敛域名。以减少可能的 dns, tcp connection 耗时
 如果未使用 HTTP 2.0，建议升级到 HTTP 2.0 提升连接复用率

 */
+ (MTHNetworkTaskInspection *)tooManyHostInspection;

@end


NS_ASSUME_NONNULL_END
