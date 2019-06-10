# MTHawkeye

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
