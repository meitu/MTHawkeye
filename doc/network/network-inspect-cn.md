# Hawkeye - Network Inspect

`Network Inspect` 插件基于 `Network Monitor`，根据记录的网络请求实际情况，侦测是否有可改进优化的项，上层可以自定义自己的规则。

## 0x00 规则

在团队开发过程中，特别是多团队合作开发的大型 App，容易因为缺乏统一的管理而导致网络使用不佳，造成对最终用户体验的影响。本模块主要基于实际的网络请求，从请求延时、带宽使用、API 使用、并发管理几个维度，默认内置了一些侦测策略：

- 侦测发起请求 URL 异常
- 侦测还在使用建议废弃的 NSURLConnection
- 侦测还在使用 HTTP/1
- 侦测未设置 HTTP timeOutIntervalForRequest
- 侦测 NSURLSessionTask 没有合理管理
- 侦测 HTTP 返回数据使用压缩
- 侦测重复下载同一数据
- 侦测 DNS 耗时异常
- 侦测 HTTP KeepAlive 未开启
- 侦测使用过多域名
- 侦测重定向请求
- 侦测启动期间的长耗时请求
- 侦测启动期间的 DNS 总体耗时
- 侦测启动期间的 TCP 连接总体耗时
- 侦测 TCP 连接复用
- 侦测 HTTP 请求任务队列优先级管理不合理

更多网络请求的整体管理策略，可参考 [iOS 网络使用实践](./network-practice.md)。

上层也可根据自己的需要，增加自定义的侦测策略

```objc
MTHNetworkTaskInspection *inspection = xxx; // 详情可参考默认内置 Inspect 的实现
[MTHNetworkTaskInspector addInspection:inspection];
```

## 0x01 使用

`Network Inspect` 接入 HawkeyeClient 后默认开启，如果需要更多该模块的相关设置可按以下操作路径进入设置

1. 启动App后，点击Hawkeye的浮窗进入主面板。
2. 点击导航栏 title，呼出 Hawkeye 面板切换界面。
3. 点击切换界面右上角的 `Setting`，进入 Hawkeye 设置主界面。
4. 找到并进入 `Network Monitor`，关闭 `Network Inspect`

对于有改进空间的项目在 `Network Inspect` 主界面会标记为红色，每个 Cell 头部的[n]表示有n个网络请求可以改进。点击进入后可看到所对应改进项的网络请求列表。

示例：

![Inspect Result List](./network-inspect-result-list.png) ![Inspect Advice Example](./network-inspect-result-advice-example.png)
