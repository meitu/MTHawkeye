# Hawkeye - FPS Trace
`FPS Trace`插件记录 FPS 刷新率并且能够显示在悬浮窗上的功能，同时这个模块支持侦测`GPUImageView`的刷新流程以提供GL-FPS。

目前Hawkeye每过0.5s会刷新一次状态和悬浮窗(`statusFlushIntevalInSeconds`)，假如`FPS Trace`所提供的记录是0.5s之前的则会直接把它丢弃，可以在`MTHawkeyeUserDefaults`中将`statusFlushKeepRedundantRecords`打开让该模块强制写入一条记录。当你把这些fps记录从文件读出来的时候需要自己去组织时间线。

## 记录存储
当`FPS Trace`插件被开启的时候，会记录`fps`和`gl-fps`到[记录文件](./../hawkeye-storage.md#0x02-built-in-plugin-data-storage-instructions)。

它们的格式如下：
```txt
colletion,key,value
...
fps,1554251562.052403,59
fps,1554251562.502282,60
gl-fps,1554251562.502299,28
```