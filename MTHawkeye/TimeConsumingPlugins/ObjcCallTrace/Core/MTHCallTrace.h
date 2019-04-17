//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 01/11/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

extern NSString *const kHawkeyeCalltraceAutoLaunchKey; /**< standardUserDefaults key, 启动时是否在 load 自动开启 CallTrace */


@class MTHCallTraceTimeCostModel;


/**
 用于 Hook objc_msgSend 方法，如果方法的耗时大于某一阈值，记录到内存里

 因目前 hook objc_msgSend 的方式会修改调用堆栈，不建议在需要保留崩溃堆栈的环境中开启

 设置下次启动自动开启后，内部的 + load 方法会做开启操作，但因不同类的 load 方法调用顺序依赖于
 文件编译顺序、静态库链接顺序，如果要监测所有 App 内的 load 方法耗时，建议新建一个 framework
 里面只实现一个 load 方法，调用 [MTHCallTrace startAtOnce]
 然后把这个 Framework 放到所有链接库的最前面，保证他的 load 方法会被最早执行

 ```
 // 以美颜工程为例，在主工程 Target 下新建一个 Framework `Pangu`, 确保在 MYXJ target 的 target dependencies 里有添加了 Pangu 并放在首位
 // 然后在 Pangu 里实现任一个类，里面只实现 load 方法，如下

 + (void)load {
 #pragma clang diagnostic push
 #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // 通过动态库注入版本，配置读取 setting bundle 里的配置信息
    Class theClass = NSClassFromString(@"MTHSettingBundlePreference");
    if (theClass) {
        [theClass performSelector:NSSelectorFromString(@"load")];
    }

    // 直接引用的版本, 配置直接使用上一次运行时的配置（保存在 NSUserDefault 里）
    Class calltraceClass = NSClassFromString(@"MTHCallTrace");
    if (calltraceClass) {
        [calltraceClass performSelector:NSSelectorFromString(@"load")];
    }
    #pragma clang diagnostic pop
 }
 ```

 */
@interface MTHCallTrace : NSObject

/**
 设置启动 App 时是否自动开启 CallTrace，重新启动后生效

 因目前 CallTrace 会影响断点/崩溃时的调用堆栈可读性，故不建议总是开启
 此类目前不提供运行中开启、关闭的方法
 */
+ (void)setAutoStartAtLaunchEnabled:(BOOL)enabled;
+ (BOOL)autoStartAtLaunchEnabled;

/**
 如果要开启 CallTrace，一般建议尽可能早的开始，以便监测包括 load 方法在内的 ObjC 方法耗时


 如果上层 App 没有做任何额外的操作，load 方法的加载顺序不可预期，有些 load 方法的耗时监测可能会漏过

 上层 App 可添加一个静态链接库(如 MTTheVeryFirst)，置顶到所有 framework 之前
 在这个库里实现 load 方法，调用本方法
 */
+ (void)startAtOnce;


+ (void)disable;
+ (void)enable;
+ (BOOL)isRunning;

+ (void)configureTraceAll;
+ (void)configureTraceByThreshold;

+ (void)configureTraceMaxDepth:(NSInteger)depth;      // 配置方法调用记录的最大层级
+ (void)configureTraceTimeThreshold:(double)timeInMS; // 配置方法调用记录的耗时阈值

+ (int)currentTraceMaxDepth;
+ (double)currentTraceTimeThreshold; // in ms

+ (NSArray<MTHCallTraceTimeCostModel *> *)records;                           // 原始排列的数据
+ (NSArray<MTHCallTraceTimeCostModel *> *)prettyRecords;                     // 原始排列的数据，将子节点移为树枝
+ (NSArray<MTHCallTraceTimeCostModel *> *)recordsFromIndex:(NSInteger)index; // 原始的排列数据，从偏移位置开始到结尾

@end
