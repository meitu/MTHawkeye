# Hawkeye - ANR Tracer

`ANR Records` 用于记录卡顿事件，同时采样卡顿发生时的主线程调用栈

## 0x00 使用

1. 启动 App 后，点击 Hawkeye 的浮窗进入主面板
2. 点击导航栏 title，呼出 Hawkeye 面板切换界面
3. 点击切换界面右上角的 `Setting`，进入 Hawkeye 设置主界面
4. 找到 `ANR Trace`, 进入开启 `Trace ANR`
5. 可以通过设置`ANR Threshold` 来设定卡顿判断阈值。

## 0x01 卡顿记录

当主线程中的某项任务执行时长超过指定阈值（默认为 400ms）时，会触发生成一次卡顿记录，并记录触发时的主线程堆栈。在 `ANR Records` 界面可看到记录的卡顿数据列表和卡顿详情

![ANR Record list](./anr-record-list.png) ![ANR Record detail](./anr-record-detail.png)

如果需要更精确的卡顿时长和堆栈信息，可考虑使用 [UI Time Profiler](./ui-time-profiler.md)

## 0x02 存储说明

ANR 的数据存储在 [Records 文件](./../hawkeye-storage-cn.md#0x02-内置插件存储数据说明) 下。`collection` 为 `anr`，`key` 为卡顿时间结束的时间点，`value` 为 json 字符串，字段说明如下：

- `time`: 卡顿事件结束时间点
- `duration`: 大约的卡顿时长
- `stackframes`: 发生时的调用堆栈取样（未符号化）,以 `,` 分隔的十六进制地址字符串

示例：

```json
{
    "stackframes":"0x1b050d908,0x1b05091fb,0x1b05091fb,0x1b043a15b,0x1029f1013,0x1029f0ccf,0x1029f0727,0x1029f0653,0x1dd932457,0x1dd9326bb,0x1dd73087b,0x1dd71e877,0x1dd74d87f,0x1b04dc7cb,0x1b04d745f,0x1b04d79ff",
    "time":1553593555.7076001,
    "duration":"1009.450078010559"
}
```

## 0x03 符号化说明

`ANR Trace` 在运行过程中记录的 stack frame 为原始内存地址，需要进行符号化以便阅读。

如果是 debug 阶段或者程序包未去除符号表，则可直接使用 `ANR Trace` 主面板进入记录详情页查看符号化后的结果。

其他情况下，如果已经[自己实现了符号化服务](./../hawkeye-remote-symbolics.md)，并做了设置，可打开 `Remote Symbolics`，再查看详情记录时会切换调用远程符号化服务。

若想在程序退出运行后，从沙盒里拿到记录的数据，则需要自己进行符号化。手动操作可按以下步骤：

1. 拿到 hawkeye 存储目录下的 `dyld-images` 文件
2. 拿到待符号化的 stack-frames 数据
3. 拿到运行包对应的符号表文件
4. 针对每一个 stack-frame，找到所在 dyld-image, 使用 `atos` 命令进行符号化
