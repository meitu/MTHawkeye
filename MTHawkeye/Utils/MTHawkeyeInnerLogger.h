//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/14
// Created by: EuanC
//


#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Foundation/Foundation.h>

@interface MTHawkeyeInnerLogger : NSObject

/**
 Don't call directly, use MTHLog/MTHLogInfo/MTHLogWarn/MTHLogError
 */
+ (void)log:(BOOL)asynchronous
      level:(DDLogLevel)level
       flag:(DDLogFlag)flag
        tag:(id __nullable)tag
     format:(nullable NSString *)format, ... NS_FORMAT_FUNCTION(5, 6);

/**
 inner log format: "mm:ss:SSS log content"

 @param logLevel Log levels are used to filter out logs. Used together with flags.
 */
+ (void)setupFileLoggerWithLevel:(DDLogLevel)logLevel;

/**
 inner log format: "[hawkeye] mm:ss:SSS log content"
 */
+ (void)setupConsoleLoggerWithLevel:(DDLogLevel)logLevel;

+ (void)configFileLoggerLevel:(DDLogLevel)logLevel;
+ (void)configConsoleLoggerLevel:(DDLogLevel)logLevel;

@end

#else // __has_include(<CocoaLumberjack/CocoaLumberjack.h>)


#endif // __has_include(<CocoaLumberjack/CocoaLumberjack.h>)
