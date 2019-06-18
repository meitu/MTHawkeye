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

extern NSInteger gMTHNetworkInspectionStartupIncludingSeconds; // default take the first 5 seconds as startup period.

extern NSString *kMTHNetworkTaskAdviceKeyParallelRequestIndexList;

@class MTHNetworkTaskInspection;


/**
 Scheduling Inspection 主要用于侦测调度相关的优化
 */
@interface MTHNetworkTaskInspectionScheduling : NSObject

/**
 Detecting heavy requests during startup (> 1.5s)

 > 目前启动时网络质量状态未知，暂时使用简单策略。后续可尝试倒推使用最近的网络质量状态

 建议:
 如果包较大，建议做拆分，减小启动期间要请求的包的大小。
 如果启动期间并发的网络请求较多，建议减少一些在启动期间不必要的网络请求，后置处理
 如果 DNS 耗时过长，建议使用 MTFastDNS 或类似方案减少 DNS 时间
 */
+ (MTHNetworkTaskInspection *)startupHeavyRequestTaskInspection;

extern NSInteger gMTHNetworkInspectionStartupHeavyTransactionCostLimit; // default 1.5s

/**
 Detecting long DNS cost during startup, > 200ms

 建议:
 建议使用 MTFastDNS 或类似的方法来减少 dns 耗时;
 如果包含多个不同 host 的 dns 请求时间，建议收敛域名;
 如果包含多个同一 host 的 dns 请求时间，建议做好优先级管理;
 */
+ (MTHNetworkTaskInspection *)startupDNSCostInspection;

extern NSInteger gMTHNetworkInspectionStartupDNSCostLimit; // default 0.2s

/**
 Detecting long TCP shake-hand during startup

 建议:
 查看多个请求是否有效利用了 HTTP 2.0 的特性，复用 TCP 连接
 如果包含多个不同 host 的 dns 请求时间，建议收敛域名
 如果包含多个同一 host 的 dns 请求时间，建议做好优先级管理
 */
+ (MTHNetworkTaskInspection *)startupTCPConnectionCostInspection;

extern NSInteger gMTHNetworkInspectionStartupTCPTimeCostLimit; // default 0.4s

/**
 Detecting HTTP task priority management
 
 Head-Of-Line Block 参见 https://developer.apple.com/videos/play/wwdc2015/711/

 建议:
 HTTP/1 协议下，因为缺少协议内置的支持，请求顺序为先进先执行，需要通过手动的请求队列管理来控制优先级；
 HTTP/2 协议下，可以结合 (合理管理 SessionTask、域名合并、priority 控制) 来快速的控制请求的优先级。
 */
+ (MTHNetworkTaskInspection *)requestTaskPriorityInspection;

/**
 Detecting time used by parallel TCP shake-hands

 策略1. 并发的多个网络请求，包含多个 host, 且同时出现并发的 tcp 握手
 建议:
 - 不同的 host 出现并发 tcp 连接，考虑是否能收敛域名
 - 同一 host 出现并发 tcp 连接，建议使用 http 2.0

 策略2. 包含 tcp 握手的链接，往前 10s 内有可复用的 host
 建议:
 - 同一 host 下 tcp 连接 10s 应该是可复用的，建议检查 http 请求头和返回头和实际的网络情况，是否启用了 http 2.0
 */
+ (MTHNetworkTaskInspection *)TCPConnectionCostInspection;

/**
 侦测应该及时取消的网络请求，如退出控制器后应该要及时取消的网络请求。
 > 目前的框架还不支持这个侦测，后续看有没有好的切入点。欢迎提 issue 或 PR, _(:з」∠)_
 */
+ (MTHNetworkTaskInspection *)shouldCancelledRequestTaskInspection;

@end


NS_ASSUME_NONNULL_END
