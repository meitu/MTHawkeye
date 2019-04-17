
# MTHawkeye Storage

MTHawkeye 运行过程中，会将插件监测到的数据，实时保存到文件中，以便在 App 关闭或者异常退出时，下次打开依然可以获取到数据，做进一步的分析。因为实时处理，顾需要减少 I/O 操作对性能的影响，最好有一个统一的高性能存储组件来处理存储事务，MTHawkeye 将 Tencent Mars 的 Xlog 组件做了精简，改写成 `MTAppenderFile` 组件用于高性能存储件，具体的实现见 [MTAppenderFile Readme](https://github.com/meitu/MTAppenderFile#mtappenderfile)。

## 0x00 MTHawkeye 数据存放根目录

每次启动 App MTHawkeye 会在 App 沙盒的 `/Documents/com.meitu.hawkeye/` 下创建一个新的文件夹，以 App 的启动时间点为名，格式为: `yyyy-MM-dd_HH:mm:ss+SSS`。 MTHawkeye 只会保留最近 10 次运行的记录，超过七天的记录也会在启动后清除。

通过增加预编译宏，可将根目录修改为 `/Library/Caches/com.meitu.hawkeye/` 或者 `/tmp/com.meitu.hawkeye/`。详见 `MTHawkeyeUtility.h` 文件

- 使用预编译宏 `MTHawkeye_Store_Under_LibraryCache 1` 切换为放到 `/Library/Caches` 下
- 使用预编译宏 `MTHawkeye_Store_Under_Tmp 1` 切换为放到 `/tmp` 下

## 0x01 MTAppenderFile 文件格式说明

每份 AppenderFile 分为两个文件，一个固定为 150KB 的高速缓存 mmap 文件，扩展名为 `.mmap2`，一个为缓存将满时转储的文件，扩展名为 `.mtlog`。如记录实时性能数据的 AppenderFile 为 records，包含了 `records.mmap2` 和 `records.mtlog` 两部分，读取时需要将两个文件合并，才是完整的 records。

### `.mmap2` 文件说明：

mmap2 文件在创建时通过 mmap 映射到内存，固定占用 150KB 内存。在写满 2/3 时，内部会将数据转储到 .mtlog 文件内，然后从头开始写入。转储完成时，考虑到性能原因，没有将整个 mmap2 文件清空，而是在每次写一行新数据时，将下一行数据填充为 `\0\0\0`。即在读取 mmap2 文件时，如果遇到包含三个空字符的行，就不能继续往下读了，后续的数据是脏数据。

## 0x02 内置插件存储数据说明 (Records file)

大多数内置插件记录的数据都放到 `records.mmap2` `records.mtlog` 下，records 的两个文件合并后，记录第一行内容为

```md
collection,key,value
```

第二行开始为实际的记录，单行内用 `,` 分隔，总共有三个字段

- 第一个字段为记录的类型，如 `cpu` 记录了运行时的 cpu 记录
- 第二个字段为 key，如 `cpu` collection 下 key 一般为记录的时间
- 第三个字段为 value, 即 `collection`:`key` 对应的 value 值

目前 MTHawkeye 内置的插件包含了以下 collection:

- `launch-time`, 启动时间，key/value 均为启动的时间
- `mem`, App 内存占用记录，key 为时间，value 为内存占用值，单位为 MB。记录的间隔时间默认为 0.5s, 如果有空缺，是因为数据没变化省略记录。
- `r-mem`, App 内存占用记录，取自 phys_footprint，日常做前后版本内存对比时可用此值。余同上。
- `cpu`, App CPU 占用记录，key 为时间，value 为 App 的 CPU 占用值，单位为 %。记录的间隔时间默认为 0.5s, 如果有空缺，是因为数据没变化省略记录。
- `fps` `gl-fps`: 内置 `FPSTrace` 插件记录的数据分组，详见 [FPSTrace 存储说明](./time-consuming/fps-tracer.md)。
- `cpu-highload` `cpu-highload-stackframe`: 内置 `CPUTrace` 插件记录的数据分组，详见 [CPUTrace 存储说明](./energy/cpu-trace-cn.md#0x02-存储数据说明)。
- `gl-mem`: 内置 `OpenGLTrace` 插件记录的数据分组，详见 [OpenGLTrace 存储说明](./graphics/opengl-trace-cn.md#0x02-存储说明)。
- `app-launch` `view-ctrl` `custom-time-event` `call-trace`: 内置 `UITimeProfiler` 插件记录的数据分组，详见 [UITimeProfiler 存储说明](./time-consuming/ui-time-profiler-cn.md#0x03-存储说明)。
- `anr`: 内置 `ANRTrace` 插件记录的数据分组，详见 [ANRTrace 存储说明](./time-consuming/anr-tracer-cn.md#0x02-存储说明)

## 0x03 MTHawkeyeStorage API 使用说明

编写一个新插件时，建议核心逻辑不包含存储部分，而应使用代理或其他形式将存储的逻辑抛给上层处理。接入 MTHawkeye 时，可使用 MTHawkeye 的 Storage 存储，或者根据使用场景使用其他存储方式存储数据。可参考 `LivingObjectsSniffer` 插件的存储。

### 使用 API 存储 records

MTHawkeyeStorage 类管理了 MTHawkeye 存储目录，同时维护一个 `records` 记录文件用于存储性能数据。所有插件，如果要存储的数据可拆分成单行，且最终的字符串数据长度小于 4K，可直接调用 MTHawkeyeStorage 提供的接口存储。

```objc
/// len(collection + value + key) to char should < 4K
- (void)syncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection;
- (void)asyncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection;
```

### 使用 API 读取 records

读取时，使用 API 一次性读取

```objc
- (NSUInteger)readKeyValuesInCollection:(NSString *)collection
                                   keys:(NSArray<NSString *> *_Nullable __autoreleasing *_Nullable)outKeys
                                 values:(NSArray<NSString *> *_Nullable __autoreleasing *_Nullable)outStrings;
```

或者分页读取：

```objc
/**
 *  read record using page filter
 *
 *  @param  pageRange           page range for reading, each page content multiple lines of string
 *  @param  inCollection        return this type of collection records in the pageRange content, if nil return all types of collection record
 *  @param  orderBy             will sort all contens between startPage to lastPage
 *  @param  usingBlock          processing bolck, will call multiple times for pageRange
 */
- (void)readKeyValuesInPageRange:(NSRange)pageRange
                    inCollection:(NSString *__nullable)inCollection
                         orderBy:(MTHawkeyeStorageOrderType)orderBy
                      usingBlock:(MTHawkeyeStoragePageFilterBlock)usingBlock;
```

### 大一些数据的存储

如果需要存储的数据较大，或者不好拆分成单行（例如 LivingObjectSniffer 模块要存储的内存存活对象，网络模块则要存储的大 response body），可获取 `[MTHawkeyeStorage storeDirectory]`，在目录下创建自己的文件并管理。
