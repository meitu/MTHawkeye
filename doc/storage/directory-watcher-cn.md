# Hawkeye - Directory Watcher

`Directory Watcher` 主要用于沙盒文件夹的大小跟踪，便于开发测试过程中发现异常的文件管理问题。同时也集成了 `FLEX` 的沙盒文件查看，并扩展支持了文件或文件夹的 `AirDrop`。

## 0x00 查看沙盒与监控目录

1. 点击 Hawkeye 的浮窗进入主面板
2. 点击导航栏 title，呼出 Hawkeye 面板切换界面
3. 点击切换界面 Navigation Title 切换到 `Storage/Directory Watcher`，进入 `Directirt Watcher` 主界面。
4. 选择 `Sandbox Home` 列表可以浏览沙盒目录下的内容。
5. 选择 `Watching Direcotry` 列表中的目录即可查看该被监控目录下的目录结构。

![Directory Watcher](./directory-watcher.png)

## 0x01 文件夹大小变化监控

`Directory Watcher` 可根据配置监听指定文件夹的大小，在超出预设值（默认200MB）时通知开发者：

- 默认会在模块启动后 5 秒开始第一次大小检测
- 之后默认每隔 40s 触发一次大小检测
- 检测次数触发达到设定值后，停止监测（默认 3 次）
- 可开启在进入后台后检测一次大小
- 可开启在进入前台后检测一次大小

## 0x02 配置监控项

1. 点击切换界面右上角的 `Setting`，进入 Hawkeye 设置主界面
2. 找到 `Storage`, 进入`Directory Watcher`设置界面

![Directory Watcher Setting](./directory-watcher-setting.png)
