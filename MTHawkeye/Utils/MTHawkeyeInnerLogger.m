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


#include "MTHawkeyeInnerLogger.h"

#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)

#import <CocoaLumberjack/DDLog.h>
#import <MTAppenderFile/MTAppenderFile.h>
#import "MTHawkeyeUtility.h"


typedef NS_ENUM(NSInteger, MTHawkeyeInnerDDLogFormatterType) {
    MTHawkeyeInnerDDLogFormatterTypeFile = 1,
    MTHawkeyeInnerDDLogFormatterTypeConsole = 2,
};

@interface MTHawkeyeInnerDDLogFormatter : NSObject <DDLogFormatter>

@property (assign, nonatomic) MTHawkeyeInnerDDLogFormatterType type;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation MTHawkeyeInnerDDLogFormatter

- (instancetype)initWithType:(MTHawkeyeInnerDDLogFormatterType)type {
    if ((self = [super init])) {
        _type = type;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4]; // 10.4+ style
        [_dateFormatter setDateFormat:@"mm:ss:SSS"];
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    if (logMessage->_message.length == 0)
        return nil;

    if (logMessage->_timestamp) {
        NSString *dateAndTime = [_dateFormatter stringFromDate:logMessage.timestamp];
        NSString *message;
        if (_type == MTHawkeyeInnerDDLogFormatterTypeFile) {
            message = [NSString stringWithFormat:@"%@ %@", dateAndTime, logMessage->_message];
        } else if (_type == MTHawkeyeInnerDDLogFormatterTypeConsole) {
            message = [NSString stringWithFormat:@"[hawkeye] %@ %@", dateAndTime, logMessage->_message];
        }
        return message;
    } else {
        return logMessage->_message;
    }
}

@end

// MARK: - Hawkeye File logger

@interface MTHawkeyeInnerDDLogFileLogger : DDAbstractLogger <DDLogger>

@property (strong, nonatomic) MTAppenderFile *logFile;
@property (copy, nonatomic) NSString *logPath;

@end

@implementation MTHawkeyeInnerDDLogFileLogger

- (void)dealloc {
    [_logFile close];
}

- (instancetype)init {
    if ((self = [super init])) {
        _logPath = [MTHawkeyeUtility currentStorePath];

        if ([[NSFileManager defaultManager] fileExistsAtPath:_logPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:_logPath error:nil];
        }

        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:_logPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"create log path failed, %@", [error localizedDescription]);
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (MTAppenderFile *)logFile {
    if (!_logFile) {
        _logFile = [[MTAppenderFile alloc] initWithFileDir:_logPath name:@"log"];
        [_logFile open];
    }
    return _logFile;
}

- (void)appWillTerminate:(NSNotification *)notification {
    [_logFile close];
}

#pragma mark Override

- (void)logMessage:(DDLogMessage *)logMessage {
    if (logMessage->_message.length == 0)
        return;

    if (_logFormatter) {
        NSString *message = [_logFormatter formatLogMessage:logMessage];
        [self.logFile appendText:message];
    } else {
        [self.logFile appendText:logMessage->_message];
    }
}

- (NSString *)loggerName {
    return @"meitu.hawkeye.inner.log";
}

@end


// MARK: - Logger

static DDLog *_mth_log = nil;
static DDTTYLogger *_ttyLogger = nil;
static MTHawkeyeInnerDDLogFileLogger *_fileLogger = nil;

@implementation MTHawkeyeInnerLogger

+ (void)log:(BOOL)asynchronous
      level:(DDLogLevel)level
       flag:(DDLogFlag)flag
        tag:(id __nullable)tag
     format:(NSString *)format, ... {
    va_list args;
    if (format) {
        va_start(args, format);

        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        DDLogMessage *logMsg = [[DDLogMessage alloc] initWithMessage:message level:level flag:flag context:0 file:@"" function:nil line:0 tag:tag options:0 timestamp:[NSDate new]];

        [_mth_log log:asynchronous message:logMsg];

        va_end(args);
    }
}

+ (void)setup {
    if (_mth_log == nil) {
        _mth_log = [[DDLog alloc] init];
    }
}

+ (void)setupFileLoggerWithLevel:(DDLogLevel)logLevel {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setup];
        _fileLogger = [[MTHawkeyeInnerDDLogFileLogger alloc] init];
        _fileLogger.logFormatter = [[MTHawkeyeInnerDDLogFormatter alloc] initWithType:MTHawkeyeInnerDDLogFormatterTypeFile];
        [_mth_log addLogger:_fileLogger withLevel:logLevel];
    });
}

+ (void)setupConsoleLoggerWithLevel:(DDLogLevel)logLevel {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setup];
        _ttyLogger = [[DDTTYLogger alloc] init];
        _ttyLogger.logFormatter = [[MTHawkeyeInnerDDLogFormatter alloc] initWithType:MTHawkeyeInnerDDLogFormatterTypeConsole];
        [_mth_log addLogger:_ttyLogger withLevel:logLevel];
    });
}

+ (void)configFileLoggerLevel:(DDLogLevel)logLevel {
    if (_fileLogger) {
        [_mth_log removeLogger:_fileLogger];
        [_mth_log addLogger:_fileLogger withLevel:logLevel];
    } else {
        [self setupFileLoggerWithLevel:logLevel];
    }
}

+ (void)configConsoleLoggerLevel:(DDLogLevel)logLevel {
    if (_ttyLogger) {
        [_mth_log removeLogger:_ttyLogger];
        [_mth_log addLogger:_ttyLogger withLevel:logLevel];
    } else {
        [self setupConsoleLoggerWithLevel:logLevel];
    }
}

@end


#endif // __has_include(<CocoaLumberjack/CocoaLumberjack.h>)
