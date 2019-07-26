# MTHawkeye

## 0.12.0
### feature
- new ANR Trace with more reliable implement, support record hard stalling events. 
- new UIBackgroundTaskIdentifier tracing plugin BackgroundTaskTrace.

### improve
- thread stack frame visible from now while `ObjcCallTrace` turn on.

### bugfix
- fix crash bug on iOS8 while tracing NSURLSessionDownloadTask.
- improve stability while writing records
- 

## 0.11.5

### bugfix
- fix AirDrop extension for FLEX 3.0.0
- fix network transaction record filter UI
- fix GPUImageView present FPS UI
- fix param `top_frames_to_skip` ignored within method `mth_stack_backgrace_of_thread`

## 0.11.4

### bugfix
- fix an stupid bug while try to fix unsafe floating value compare on 0.11.3. 

## 0.11.3

### bugfix
- fix missing ViewController method invoking while work with RAC or Aspects.

### improve
- improve App Launch tracing, remove hardcode.
- use file instead of custom NSUserDefaults, improve robust.
- warning fix.

## 0.11.2

### improve
- support `use_frameworks!` under Swift projects (remove cpp header from public_header_files)
- support landscape orientation
- simplify UI logics
- exclude GraphicsPlugins/MTGLTrace from podspec by default

### bugfix
- fix memory leaks in ANR, CPU tracing plugins
- fix may crashed when remove KVO from key window

## 0.11.1

### feature
- store title frame into ANR record
- support Airdrop while browsing files under DirectoryWatcher

### bugfix
- fix crash will tracing unexpected living objc object
- fix confusing attributes for view-ctrl life-cycle trace record
- fix "toast-warning-for-unexpected-vc" UI setting crash
- fix missing dyld_images files
- fix endless loop calling while setting network / directoryWatcher settings at startup

## 0.11.0
