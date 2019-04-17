# Hawkeye - Network Practice

本文主要记录 iOS HTTP 网络开发过程中的一些实践，用以帮助改善 App 整体的网络请求管理，提升带宽的利用率，减少延时，减少电量的消耗，以提升用户体验。

#### URLConnection -> URLSession

NSURLSession 通过共享 session 来复用可用的 tcp 连接，减少了网络请求连接延时时间。
同时，NSURLSession 开始支持了 HTTP 2.0 协议，而启用 HTTP 2.0 更有利于做后续的网络优化操作。

#### HTTP/1.1 -> HTTP/2.0

建议升级到 HTTP/2.0 以获得更多的优化空间

- HTTP/2.0 同一 host 下有多个请求并发时，只创建了一个 tcp 连接。同场景下相比 HTTP/1.1 减少了多路 tcp 连接的耗时。
- HTTP/2.0 采用二进制协议，为流量控制、优先级、server push 提供了基础
- HTTP/2.0 支持多路复用，HTTP/1.0 中一个连接只能有一个请求，HTTP/1.1 中一个连接同时可以有多个请求，但一次只能有一个响应，会造成 Head-of-line Blocking 问题，HTTP/2.0 则可以多路复用，解决 Head-of-line Blocking 的问题。
- HTTP/2.0 使用 HPACK 格式压缩头部，减少了传输包的大小
- HTTP/2.0 可以设置请求的优先级，HTTP/1.1 只能按照进入的先后顺序
- HTTP/2.0 支持服务器 push 操作，可以减少一些场景下的来回路程耗时

#### timeoutInterval Optimize

timeoutIntervalForRequest 为两个数据包之间的最大时间间隔，在正常情况下，我们可以设置一个相对合理的超时时间来更快侦测到网络不可用的状态。
因为不同网络连接质量下，情况不同，建议最高设置为 30s，即连续 30s 没有收到下一个包则置为请求超时。
如果有侦测网络质量，建议做区分 (unknown/poor: 30s, moderate: 15s, good: 8s, excellent: 5s)

注意: NSURLRequest & NSURLSessionConfiguration 同时设置的情况下将会取更激进的策略

timeoutIntervalForResource 为整个任务(上传/下载)的最长完成时间，默认值为1周。因跟包大小和排队时间相关，目前没有具体建议值。

#### 合理管理 SessionTask

同一 host 下的请求尽量使用同一 Session 创建管理，以便在 HTTP/2 下更好的复用 tcp 连接通道。

#### HTTP Content-Type

设置 HTTP Accept-Encoding，开启 HTTP 内容压缩，以减少网络返回包的大小，加快请求速度。

#### 使用缓存，减少重复的网络请求

针对一些返回的数据，根据业务需要，可直接缓存到本地，减少发起网络请求的次数。
如果是需要及时刷新的数据，建议使用 HTTP Cache-Control ，减少检查更新时的不必要数据包下载带宽占用。

#### 使用合适的图片质量、图片格式

低速网络下使用合适的图片质量，减少对带宽的占用，加快整体的网络请求速度。
尽量使用压缩比较高的图片格式(如 WebP / SharpP / APNG), 同等质量的图片下，占用更小的带宽资源。

#### 使用 DNS 优化方案

考虑使用 FastDNS 或类似的方案，以减免 DNS 的耗时，减少网络请求延时。

#### 减少 HTTP 重定向的使用

移动网络环境下，减少 HTTP 重定向的使用，以减少网络请求整体耗时；
特别是不同域名间的重定向，还可能增加多次 DNS / TCP Connection 耗时。

#### 无特殊需求，不要关闭 keep-alive

HTTP/1 默认情况下 keep-alive 为开启，以在一个请求结束后不会马上中断，10秒内的下一个同 host 请求能复用同一个连接，减少不必要的连接延时。

#### 合并域名

尽量不要使用过多的二级域名，可参考 [美团点评移动网络优化之——域名合并](https://tech.meituan.com/SharkSDK.html) 进行域名合并。移动网络环境下不管使用 HTTP/1 还是 HTTP/2，过多的域名都不利于网络连接的复用，容易增多不必要的建立连接延时。

#### 启动优化

启动期间，假定为 5 秒内。尽量只发起最关键的网络请求(特别在网络质量不好的环境下)，等待关键请求完成之后，再进行后续其他请求的处理，以避免其他次要优先级的请求抢占关键请求的带宽资源。
同时，结合其他实践（合并域名、DNS 优化、HTTP/2），可减少启动时的请求延时。

#### 优先级管理

平时的业务网络请求中，建议做好优先级管理，以减少关键请求被其他次要优先级请求阻塞的情况。
HTTP/1 协议下，因为缺少协议内置的支持，请求顺序为先进先执行，需要通过手动的请求队列管理来控制优先级；
HTTP/2 协议下，可以结合 (合理管理 SessionTask、域名合并、priority 控制) 来快速的控制请求的优先级。

注意减少 Head-of-Line Blocking 在实际场景中的影响，详见 [WWDC 711 networking with nsurlsession](https://developer.apple.com/videos/play/wwdc2015/711/)
