# Hawkeye - ANR Tracer

`ANR Records` 用于记录卡顿/卡死事件，同时采样卡顿发生时的主线程调用栈

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

## 0x02 卡死记录

每次启动时，可通过  `MTHANRTracingBuffer` 获取到上一次是否是卡死状态退出。

### 界面说明

如果上一次 `Hawkeye` 的 `ANRTrace` 模块有开启，运行时卡死，下一次运行，进入到 `Hawkeye` 的 `ANR Records` 界面，列表的最后一个 section 会展示这次卡死记录。

标题为 `Previous session exit unexptected`，副标题展示了卡住的时间。

### 接口调用说明

如果上层要在启动时统计上报卡死事件，可参考 `Hawkeye` 里 `[MTHANRTracingBufferRunner readPreviousSessionBufferAtPath:completionHandler:]` 的代码调用逻辑，根据自己需要上报记录。目前记录了以下数据：

- 程序退出前的最后 30 次主线程 runloop activity
- 程序退出前的最后 10 次 App 生命周期记录
- 卡顿/卡死发生时记录到的主线程调用栈 （最多保留 500 帧)

可根据接口提供的数据，读取卡死了多长时间，卡死后捕获到的主线程的调用栈记录。

## 0x03 存储说明

ANR 的数据存储在 [Records 文件](./../hawkeye-storage-cn.md#0x02-内置插件存储数据说明) 下。`collection` 为 `anr`，`key` 为卡顿时间结束的时间点，`value` 为 json 字符串，字段说明如下：

- `duration`: 卡顿时长（毫秒）
- `stacks`: 卡顿周期内记录到的主线程堆栈
- `titleframe`: 卡顿堆栈标题
- `time`: 卡顿堆栈记录时间点
- `stackframes`: 发生时的调用堆栈取样（未符号化）,以 `,` 分隔的十六进制地址字符串

示例：

```json

{
    duration = "7352.797031402588";
    stacks = [
        {
            stackframes = 0x10d1f64ae;
            time = "1561618437.344688";
            titleframe = 0x10d1f64ae;
        },
        {
            stackframes = "0x10d1f5b1f,0x10d1efe7f,0x10d19c407,0x107203a1e,0x107203717,0x1072031dd,0x107203119,0x11545e418,0x11545e62c,0x11524ecc8,0x11523e198,0x11526b32a,0x10d1b80f6,0x10d1b25bd,0x10d1b2c30,0x10d1b2301,0x10ecf02fd,0x115243ba1,0x10720e2e1,0x10d877540";
            time = "1561618437.448422";
            titleframe = 0x107203a1e;
        },
        {
            stackframes = "0x10d1efc16,0x10d19c407,0x107203a1e,0x107203717,0x1072031dd,0x107203119,0x11545e418,0x11545e62c,0x11524ecc8,0x11523e198,0x11526b32a,0x10d1b80f6,0x10d1b25bd,0x10d1b2c30,0x10d1b2301,0x10ecf02fd,0x115243ba1,0x10720e2e1,0x10d877540";
            time = "1561618437.601369";
            titleframe = 0x107203a1e;
        },
        {
            stackframes = "0x10bd64660,0x107203717,0x1072031dd,0x107203119,0x11545e418,0x11545e62c,0x11524ecc8,0x11523e198,0x11526b32a,0x10d1b80f6,0x10d1b25bd,0x10d1b2c30,0x10d1b2301,0x10ecf02fd,0x115243ba1,0x10720e2e1,0x10d877540";
            time = "1561618437.803538";
            titleframe = 0x107203717;
        },
        {
            stackframes = "0x1072039e9,0x107203717,0x1072031dd,0x107203119,0x11545e418,0x11545e62c,0x11524ecc8,0x11523e198,0x11526b32a,0x10d1b80f6,0x10d1b25bd,0x10d1b2c30,0x10d1b2301,0x10ecf02fd,0x115243ba1,0x10720e2e1,0x10d877540";
            time = "1561618438.056277";
            titleframe = 0x1072039e9;
        },
                {
            stackframes = "0x10dbd8ce4,0x10d1e0853,0x10d1efedd,0x10d19c407,0x107203a1e,0x107203717,0x1072031dd,0x107203119,0x11545e418,0x11545e62c,0x11524ecc8,0x11523e198,0x11526b32a,0x10d1b80f6,0x10d1b25bd,0x10d1b2c30,0x10d1b2301,0x10ecf02fd,0x115243ba1,0x10720e2e1,0x10d877540";
            time = "1561618438.359641";
            titleframe = 0x107203a1e;
        }
    ]
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
