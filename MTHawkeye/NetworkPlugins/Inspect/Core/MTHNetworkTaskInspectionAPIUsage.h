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


#import "MTHNetworkTaskInspection.h"

NS_ASSUME_NONNULL_BEGIN


@class MTHNetworkTaskInspection;

/**
 API Usage Inspection 主要用于侦测 API 使用上的一些建议
 */
@interface MTHNetworkTaskInspectionAPIUsage : NSObject

/**
 Detecting URL creation result is nil

 eg:
 NSURL *url = [NSURL URLWithString:@" http://www.host.com"];
 NSURL *url = [NSURL URLWithString:@"http://www.host.com?中文"];

 会返回 nil，直接拿这个去请求网络会失败。

 Hook NSURL 的 Designed 创建方法，用于记录可能的 URL 失败错误。默认开启
 */
+ (MTHNetworkTaskInspection *)nilNSURLInspection;

/**
 Detecting URL exceptions for the request

 侦测 url 异常的情况(bad, unsupport) 的请求.（后续需要增加记录原始 urlstring，方便排查）
 */
+ (MTHNetworkTaskInspection *)unexpectedURLRequestInspection;

/**
 Detecting the use of deprecated NSURLConnection API

 NSURLSession 通过共享 session 来复用可用的 tcp 连接，减少了网络请求连接延时时间。
 同时，NSURLSession 开始支持了 HTTP 2.0 协议，而启用 HTTP 2.0 更有利于做后续的网络优化操作。

 */
+ (MTHNetworkTaskInspection *)deprecatedURLConnectionInspection;

/**
 Detecting has not yet use HTTP/2

 HTTP 2.0 优势
 - HTTP/2 同一 host 下有多个请求并发时，只创建了一个 tcp 连接。同场景下相比 HTTP/1.1 减少了多路 tcp 连接的耗时。
 - HTTP/2 采用二进制协议，为流量控制、优先级、server push 提供了基础
 - HTTP/2 支持多路复用，HTTP/1.0 中一个连接只能有一个请求，HTTP/1.1 中一个连接同时可以有多个请求，但一次只能有一个响应，会造成 Head-of-line Blocking 问题，HTTP/2 则可以多路复用，解决 Head-of-line Blocking 的问题。
 - HTTP/2 使用 HPACK 格式压缩头部，减少了传输包的大小
 - HTTP/2 可以设置请求的优先级，HTTP/1.1 只能按照进入的先后顺序
 - HTTP/2 支持服务器 push 操作，可以减少一些场景下的来回路程耗时


 ref: https://github.com/creeperyang/blog/issues/23 HTTP2 简介及基于 HTTP2 的 Web 前端优化

 */
+ (MTHNetworkTaskInspection *)preferHTTP2Inspection;

/**
 Detecting the use of default timeout

 - 不同网络状况下，建议使用不同的 timeoutIntervalForRequest 超时策略（默认 60s)
 (poor: 30s, moderate: 15s, good: 8s, excellent: 5s)

 - 不同包大小&网络状况下，考虑使用不同的 timeoutIntervalForResource 超时策略（默认一周）

 建议:
 timeoutIntervalForRequest 为两个数据包之间的最大时间间隔，在正常情况下，我们可以设置一个相对合理的超时时间来更快侦测到网络不可用的状态。
 因为不同网络连接质量下，情况不同，建议最高设置为 30s，即连续 30s 没有收到下一个包则置为请求超时。
 如果有侦测网络质量，建议做区分 (unknown/poor: 30s, moderate: 15s, good: 8s, excellent: 5s) 具体分档见 MTHNetworkStat.h
 注意: NSURLRequest & NSURLSessionConfiguration 同时设置的情况下将会取更激进的策略 （存疑，待确认)

 timeoutIntervalForResource 为整个任务(上传/下载)的最长完成时间，默认值为1周。因跟包大小和排队时间相关，目前没有具体建议值。
 */
+ (MTHNetworkTaskInspection *)timeoutConfigInspection;

/**
 Detecting improper use of NSURLSessionTask
 侦测多个同一类型的 task 没有使用同一 Session 管理

 同一 host 下，尽量使用同一 session 来管理所有请求 task，以复用网络连接
 */
+ (MTHNetworkTaskInspection *)urlSessionTaskManageInspection;

@end


NS_ASSUME_NONNULL_END
