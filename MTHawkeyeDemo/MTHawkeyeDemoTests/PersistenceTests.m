//
//  PersistenceTests.m
//  MTHawkeyeDemoTests
//
//  Created by Huni on 14/06/2018.
//  Copyright © 2018 Meitu. All rights reserved.
//

#import <MTAppenderFile.h>
#import <MTHMemoryDebugger.h>
#import <MTHawkeye/MTHawkeyePersistance.h>
#import <MTHawkeyeSetting.h>
#import <MTHawkeyeUtility.h>
#import <XCTest/XCTest.h>

static NSString *const kRealtimeRecordsFileName = @"records";

@interface PersistenceTests : XCTestCase

@property (nonatomic, strong) MTHawkeyePersistance *storage;
@property (nonatomic, strong) NSString *storeDirectory;
@property (nonatomic, strong) MTAppenderFile *realtimeRecordsFile;
@property (nonatomic, strong) dispatch_queue_t storeQueue;

@end

@implementation PersistenceTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _storage = [MTHawkeyePersistance defaultStorage];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testWrite {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr;
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        self.storeQueue = dispatch_queue_create("com.meitu.hawkeye.storage", attr);
    });

    self.storeDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"/com.meitu.hawkeye"];

    MTAppenderFile *file = [[MTAppenderFile alloc] initWithFileDir:self.storeDirectory name:kRealtimeRecordsFileName];
    [file open];

    // header
    [file appendText:@"collection,key,value"];

    // launch time
    NSString *launchTime = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility appLaunchedTime])];
    NSString *launchInfo = [NSString stringWithFormat:@"%@,%@,%@", @"launch-time", launchTime, launchTime];
    [file appendText:launchInfo];

    self.realtimeRecordsFile = file;

    [self measureBlock:^{
        for (int i = 0; i < 1000000; i++) {
            NSString *time = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility currentTime])];

            static NSString *preMemUsage = nil;
            CGFloat curMemUsageInMB = [MTHMemoryDebugger shared].memoryUsageCurrentInMB;
            NSString *curMemUsage = [NSString stringWithFormat:@"%.0f", curMemUsageInMB];
            if (![curMemUsage isEqualToString:preMemUsage]) {
                preMemUsage = curMemUsage;
                dispatch_async(self.storeQueue, ^(void) {
                    NSString *recordLine = [NSString stringWithFormat:@"%@,%@,%@", MTHPersistenceMemoryCollectionKey, time, curMemUsage];
                    [self.realtimeRecordsFile appendText:recordLine];
                });
                //                NSString *recordLine = [NSString stringWithFormat:@"%@,%@,%@", MTHPersistenceMemoryCollectionKey, time, curMemUsage];
                //                [self.realtimeRecordsFile appendText:recordLine];
            }
        }
    }];
}

- (void)testRead {
    self.storeDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"/com.meitu.hawkeye"];
    MTAppenderFile *file = [[MTAppenderFile alloc] initWithFileDir:self.storeDirectory name:kRealtimeRecordsFileName];
    [file open];

    [self measureBlock:^{
        for (int i = 0; i < 1000000; i++) {
            NSString *filePath = [self.storeDirectory stringByAppendingPathComponent:kRealtimeRecordsFileName];
            NSString *mmapPath = [filePath stringByAppendingPathExtension:@"mmap2"];
            filePath = [filePath stringByAppendingPathExtension:@"mtlog"];

            NSMutableString *logs = [NSMutableString string];
            NSString *fileString = [NSString stringWithContentsOfFile:filePath usedEncoding:NULL error:nil];
            if (fileString) {
                [logs appendString:fileString];
            }

            NSString *mmapString = [NSString stringWithContentsOfFile:mmapPath usedEncoding:NULL error:nil];
            // mmap 被转储到日志文件后，mmap 第一个字可能会被直接标为 | \0 |
            if (mmapString && [mmapString characterAtIndex:0] != '\0') {
                [logs appendString:mmapString];
            }
        }
    }];
}

@end
