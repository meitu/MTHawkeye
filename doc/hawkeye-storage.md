
# MTHawkeye Storage

While MThawkeye running, the data collected by the plugins will be saved to the file in time, so that when the App crash or exist unexpected, the record data can be obtained for further analysis.

Because of the need to reduce the impact of I/O operations on performance, it is best to have a unified high-performance storage component for plugins to handle storage transactions. MTHawkeye has streamlined [Tencent Mars' Xlog](https://github.com/Tencent/mars) components to the `MTAppenderFile` for high-performance storage, see [MTAppenderFile Readme](https://github.com/meitu/MTAppenderFile#mtappenderfile)) for detail.

## 0x00 MTHawkeye storage root directory

Each time App launched, MTHawkeye will create a new folder under `/Documents/com.meitu.hawkeye/` in the App sandbox, name with the App launched time, formate as `yyyy-MM-dd_HH:mm:ss+SSS`. MTHawkeye will keeps records for the last 10 runs, and records order than seven days will cleared after App launched.

By adding a preprocessor macro, you can change the root directory to `/Library/Caches/com.meitu.hawkeye/` or `/tmp/com.meitu.hawkeye/`. See the `MTHawkeyeUtility.h` file for details.

- Use the preprocessor macro `MTHawkeye_Store_Under_LibraryCache 1` to switch to `/Library/Caches/com.meitu.hawkeye/`
- Use the preprocessor macro `MTHawkeye_Store_Under_Tmp 1` to switch to `/tmp/com.meitu.hawkeye/`

## 0x01 MTAppenderFile file format

Each `AppenderFile` contains two files with the same file name, and different extensions. The first one is mmap file for high speed cache with the extension `.mmap2`, it's size is 150KB. The other file a extension `.mtlog`, log data transferred to this file when the mmap file needs to be dumped.

For example, if you create an `AppenderFile` whose name is records, the actual files are: `records.mmap2` and `records.mtlog`. You need to merge the two files when reading, which is the complete records.

Attention for reading stored data:

- Both files need to be read, first `*.mmap2`, then `*.mtlog`, and then put the content together.
- When reading the `*.mmap2` file, only non-dirty data is needed. when the `\0\0\0` line is encountered, the complete content of `mmap` has been read, and the content after that is dirty data, which should be ignored.

## 0x02 Built-in plugin data storage instructions (Records file)

Some of the data recorded by the built-in plugin is saved to `records.mmap2` `records.mtlog`, after merged the two files, the first line is

```md
collection,key,value
```

Starts from the second line is the records, one record one line, each line separated by `,`, and there are three fields in total

- the first field is the record `collection` name
- the second field is `key`
- the third field is `value`

Currently, MTHawkeye's built-in plugins use the following collection when using `records appenderfile`:

- `launch-time`, App launched time record，key/value are both the App launched time.
- `mem`, App memory usage records, `key` is the record time, `value` is the memory usage value. The interval between records defaults to 0.5s, when the `MTHawkeyeUserDefaults statusFlushKeepRedundantRecords` off (by default), records will be omitted will same as previous node.
- `r-mem`, App memory footprint records, from phys_footprint, else same as `mem`.
- `cpu`, App CPU usage records, key is the record time, value is the CPU usage of the App, in %.
- `fps` `gl-fps`: collection record by built-in plugin `FPSTrace`, see [FPSTrace storage](./time-consuming/fps-tracer.md)。
- `cpu-highload` `cpu-highload-stackframe`: collection record by built-in plugin `CPUTrace`, see [CPUTrace storage](./energy/cpu-trace.md#0x01-storage).
- `gl-mem`: collection record by built-in plugin `OpenGLTrace`, see [OpenGLTrace storage](./graphics/opengl-trace.md#storage).
- `app-launch` `view-ctrl` `custom-time-event` `call-trace`: collection record by built-in plugin `UITimeProfiler`, see [UITimeProfiler storage](./time-consuming/ui-time-profiler.md#0x03-storage).
- `anr`: collection record by built-in plugin `ANRTrace`, see [ANRTrace storage](./time-consuming/anr-tracer.md#0x02-storage)

## 0x03 MTHawkeyeStorage API Instruction

When you write a plugin, it's recommended that the core logic doesn't contain the storage part, and the storage logic should be thrown to the upper layer using a proxy or other form. When add it to MTHawkeye, you can use MTHawkeyeStorage to do the storage, or use other storage strategy base on your scenarios such as `MTHLivingObjectsSnifferHawkeyeAdaptor`.

### Use API to store records

`MTHawkeyeStorage` class manages the storage directory, and maintaining a `records` `appenderfile`  for storing performance data. For all plugins, if the record can be split into a single line, and the final string data length is less than 4K, you can directly use the following API provided by `MTHawkeyeStorage`.

```objc
/// len(collection + value + key) to char should < 4K
- (void)syncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection;
- (void)asyncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection;
```

### Use API to read records

Read all records:

```objc
- (NSUInteger)readKeyValuesInCollection:(NSString *)collection
                                   keys:(NSArray<NSString *> *_Nullable __autoreleasing *_Nullable)outKeys
                                 values:(NSArray<NSString *> *_Nullable __autoreleasing *_Nullable)outStrings;
```

or read records with page range:

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

### For larger data

If the record is large than limit, or it can't be split into single lines (such as LivingObjectSniffer, NetworkMonitor), you can get storage directory from `[MTHawkeyeStorage storeDirectory]` and create your own files in the directory, then operate it by yourself.
