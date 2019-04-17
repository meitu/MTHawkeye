# Hawkeye - Network Monitor

`Network Monitor` 监听记录 App 内 HTTP(S) 网络请求的各个阶段耗时，并提供内置的记录查看界面，便于开发者排查优化网络问题。

## 0x00 背景

在日常开发测试过程中，常会有需要查看具体网络请求进行问题排查的场景，常见的有几种操作：

1. 打日志 + 断点调试
2. 利用第三方软件如 `WireShark`, `Charles` 等进行代理抓包
3. 在 Debug 环境接入 `FLEX` 监听 App 内的网络请求

`FLEX` 相对是一个比较便捷的方式，但相对功能需要做一些改进，以便适用于更多场景。目前 `Network Monitor`主要包含了以下几部分内容：

1. 继承自 `FLEX` 的网络请求记录，过滤搜索。同时优化监听初始化逻辑，大幅减少对启动时间的影响
2. 针对 iOS 9 后的 `NSURLSession` 的请求，增加记录 `URLSessionTaskMetrics` 方便查看请求各个阶段的时间
3. 基于 `URLSessionTaskMetrics` 增加类似 Chrome 网络调试的 waterfall 视图，方便查看网络请求的队列和并发情况
4. 增加重复网络请求的侦测
5. 增强搜索栏，支持多条件搜索（域名筛选、重复请求、url 过滤、status 过滤）
6. 记录展示完整的网络请求记录（增加 request headers, request body, response body 记录）

## 0x01 使用

将 `Network Monitor` 加入 `HawkeyeClient` 后， `Hawkeye` 启动后默认开启监测，如果需要更多该模块的相关设置可按以下操作路径进入设置：

1. 启动 App 后，点击 Hawkeye 的浮窗进入主面板。
2. 点击导航栏 title，呼出 Hawkeye 面板切换界面。
3. 点击切换界面右上角的 `Setting`，进入 Hawkeye 设置主界面。
4. 找到并进入 `Network Monitor`。

### 界面交互说明

#### 历史请求记录主界面

网络请求记录结果主界面可以分为三个大部分，从上到下分别是：

* 搜索栏、筛选条件设置（分别为下方的居中示例图，居右示例图）
* 当前选中请求及其并发请求的 waterfall 视图
* 历史记录请求列表

<img src="./network-monitor-records-main.png" width=290><img src="./network-monitor-records-search.png" width=290><img src="./network-monitor-records-filter-panel.png" width=290>

其中搜索栏支持简单的过滤参数

* `d`，用于显示所有重复的网络请求
* `s 1/2/3/4/5/f`，用于过滤返回状态，如`s 4`表示显示所有返回 4xx 的请求，`s f`表示显示所有失败的请求
* `url filter`，用于显示部分匹配 url 的请求，直接输入对应的url字符串

例如输入 `d s f meitu.com` 表示显示所有链接包含 `meitu.com` 且重复的失败请求。

搜索栏右侧的按钮点击后，可打开 `Filter` 视图，用于筛选查看网络请求。

##### 并发网络请求 waterfall 视图

搜索栏以下，列表视图以上为 waterfall 视图。选中列表里的一个网络请求后，会显示时间纬度上并行的所有网络请求。 waterfall 底部为时间轴，时间长度为这些并发请求总经历的时长，waterfall 列表行，左侧为请求编号，与下面历史记录请求列表左侧的编号对应。

网络请求记录在 waterfall 列表中有两种样式，一种为包含 `URLSessionTaskMetrics` 数据的请求（如下方左图），一种为没有详细耗时的请求（如下方有图）：

![with metrics](./network-monitor-waterfall-with-metrics.png) ![without metrics](./network-monitor-waterfall-without-metrics.png)

包含 `URLSessionTaskMetrics` 数据的请求图示包含了不同粗细的部分，分别表示一个网络请求的多个阶段，说明如下

![Transaction metrics](./network-monitor-transaction-metrcis.png)

其中各字段表示为

* `Queueing`: request task 的排队耗时
* `DNS`: 域名解析耗时，如果本地包含域名解析缓存，此部分可能为0
* `Connection`: TCP 握手耗时，如果连接有重用，此部分可能为0
* `Secure Connection`: TLS 握手耗时，如果连接有重用，此部分可能为0
* `Send Request`: 请求包发出开始到发出结束的耗时，未包含到达服务器的耗时
* `Receive Response`: 接受包开始到接受包结束的耗时，未包含第一个包到达前的路程耗时
* 在每个请求的耗时之后的字母表示为当前估算的网络质量，目前网络请求的质量分为以下几种状态：
  * `u` (unknown): 已完成的网络请求数太少(< 3), 未能估算
  * `p` (poor): < 150 kbps
  * `m`(moderate): 150 ~ 550 kbps
  * `g` (good): 550 ~ 2000 kbps
  * `e` (excellent): > 2000 kbps

> 网络请求的质量估算的依据来自于每个请求的下载耗时，其中耗时时长等于 "requestEnd + mid(requestEnd + receiveStart) / 2" ~ "receiveEnd" 这段时间，因下载的起始时间只能通过估算，所以存在一定偏差。如果估算得到的网络质量比实际的网络质量要差两三个量级，则可能整体的网络连接策略有优化空间
> 估算做了一定的网络质量波动冗余处理，具体算法可查看`MTHawkeyeNetworkExponentialGeometricAverage`类

waterfall 视图仅展示比例关系，各阶段的耗时数值可进入到详情页后查看。

> 如果该请求有包含重定向，则图形上只会显示最后一个请求的完整细节，其他请求段的耗时可进入到请求详情界面查看。

##### 历史网络请求列表视图

最下面的列表按时间倒序显示了记录的所有网络请求，Header 的 label 记录了所有请求流量大小，每个请求包含了如下元素：

* 开头的 label 展示了 `请求编号: url.lastPathComponent + query`. 如果请求失败，label 为红色
* 中间的 label 展示请求的 `url.host + url.paths.trimLast`
* 最下方的 label 展示 `请求发起时间 · 请求类型 · http status · 总时间 (起始时间到开始接收到返回数据的时间) · 数据包大小（Request + Reponse）`
* Cell 背景色 (`淡蓝色`: 当前选中请求；`淡灰色`：与淡蓝色并发的请求；`白色`：其他）
* 右侧灰色区域块：点击可以进入请求记录详情页
* 右侧灰色区域块可能显示的 `3/3` 为 `Network Inspect` 侦测到的问题或优化结果数量，按等级用 / 区分。可以通过 `Filter` 面板来过滤显示这一部分

![Transaction list](./network-monitor-transaction-list.png)

#### 历史请求记录详情页面

请求记录的详情界面分成了几个 Section，分别为

* `Advice`: 请求的改进建议项（来自 Network Inspect）
* `General`: 请求概要信息
* `Request`: Request AllHTTPHeaderFields & Request Body
* `Response`: Response AllHTTPHeaderFields & Response Body

这部分数据，可以通过点击右上角的按钮，使用 Copy 和 AirDrop 功能导出。

![Transaction detail 1](./network-monitor-transaction-detail-1.png) ![Transaction detail 2](./network-monitor-transaction-detail-2.png)
