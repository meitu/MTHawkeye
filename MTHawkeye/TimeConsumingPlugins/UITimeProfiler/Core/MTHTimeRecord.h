//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/8
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface MTHTimeIntervalCustomEventRecord : NSObject

@property (nonatomic, assign) NSTimeInterval timeStamp;
@property (nonatomic, copy) NSString *event;
@property (nonatomic, copy, nullable) NSString *extra;

@end

/****************************************************************************/
#pragma mark -

typedef NS_ENUM(NSInteger, MTHAppLaunchStep) {
    MTHAppLaunchStepAppLaunch = 0,          // 点击开始启动
    MTHAppLaunchStepObjcLoadStart,          // ObjC setup 结束，Initializer 开始。第一个 load 方法被调用的时间
    MTHAppLaunchStepObjcLoadEnd,            // 最后一个 load 方法被调用结束的时间
    MTHAppLaunchStepStaticInitializerStart, // C++ 静态全局变量初始化开始
    MTHAppLaunchStepStaticInitializerEnd,   // C++ 静态全局变量初始化结束
    MTHAppLaunchStepApplicationInit,        //
    MTHAppLaunchStepAppDidLaunchEnter,
    MTHAppLaunchStepAppDidLaunchExit,
    MTHAppLaunchStepUnknown,
};

@interface MTHAppLaunchRecord : NSObject

@property (nonatomic, assign) NSTimeInterval appLaunchTime; /**< App 进程创建时间 (procInfo.kp_proc.p_un.__p_starttime) */

@property (nonatomic, assign) NSTimeInterval firstObjcLoadStartTime;     /**< ObjC setup 结束，Initializer 开始。第一个 load 方法被调用的时间 */
@property (nonatomic, assign) NSTimeInterval lastObjcLoadEndTime;        /**< 最后一个 load 方法被调用结束的时间 */
@property (nonatomic, assign) NSTimeInterval staticInitializerStartTime; /**< C++ 静态全局变量初始化开始 */
@property (nonatomic, assign) NSTimeInterval staticInitializerEndTime;   /**< C++ 静态全局变量初始化结束 */

@property (nonatomic, assign) NSTimeInterval applicationInitTime;
@property (nonatomic, assign) NSTimeInterval appDidLaunchEnterTime;
@property (nonatomic, assign) NSTimeInterval appDidLaunchExitTime;

@property (nonatomic, copy, nullable) NSArray *runloopActivities; /**< 主线程 RunLoop 启动后的前 50 个 activities。 */

+ (NSString *)displayNameOfStep:(MTHAppLaunchStep)step;

- (NSTimeInterval)timeStampOfStep:(MTHAppLaunchStep)step;

@end


/****************************************************************************/
#pragma mark -

typedef NS_ENUM(NSInteger, MTHViewControllerLifeCycleStep) {
    MTHViewControllerLifeCycleStepInitExit = 0,
    MTHViewControllerLifeCycleStepLoadViewEnter,
    MTHViewControllerLifeCycleStepLoadViewExit,
    MTHViewControllerLifeCycleStepViewDidLoadEnter,
    MTHViewControllerLifeCycleStepViewDidLoadExit,
    MTHViewControllerLifeCycleStepViewWillAppearEnter,
    MTHViewControllerLifeCycleStepViewWillAppearExit,
    MTHViewControllerLifeCycleStepViewDidAppearEnter,
    MTHViewControllerLifeCycleStepViewDidAppearExit,
    MTHViewControllerLifeCycleStepUnknown,
};

@interface MTHViewControllerAppearRecord : NSObject

@property (nonatomic, copy) NSString *objPointer;
@property (nonatomic, copy) NSString *className;

@property (nonatomic, assign) NSTimeInterval initExitTime;
@property (nonatomic, assign) NSTimeInterval loadViewEnterTime;
@property (nonatomic, assign) NSTimeInterval loadViewExitTime;
@property (nonatomic, assign) NSTimeInterval viewDidLoadEnterTime;
@property (nonatomic, assign) NSTimeInterval viewDidLoadExitTime;
@property (nonatomic, assign) NSTimeInterval viewWillAppearEnterTime;
@property (nonatomic, assign) NSTimeInterval viewWillAppearExitTime;
@property (nonatomic, assign) NSTimeInterval viewDidAppearEnterTime;
@property (nonatomic, assign) NSTimeInterval viewDidAppearExitTime;

+ (NSString *)displayNameOfStep:(MTHViewControllerLifeCycleStep)step;

- (double)appearCostInMS; // in millisecond
- (NSTimeInterval)timeStampOfStep:(MTHViewControllerLifeCycleStep)step;

@end


/****************************************************************************/
#pragma mark -

@interface MTHRunloopActivityRecord : NSObject

@property (nonatomic, assign) NSTimeInterval timeStamp;
@property (nonatomic, assign) CFRunLoopActivity activity;

@end


NS_ASSUME_NONNULL_END
