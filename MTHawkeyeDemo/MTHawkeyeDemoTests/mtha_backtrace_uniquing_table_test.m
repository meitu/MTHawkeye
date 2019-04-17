//
//  mtha_backtrace_uniquing_table_test.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 2018/10/31.
//  Copyright © 2018 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "mtha_backtrace_uniquing_table.h"

@interface mtha_backtrace_uniquing_table_test : XCTestCase {
    mtha_backtrace_uniquing_table *uniquing_table;
}

@end

@implementation mtha_backtrace_uniquing_table_test

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    uniquing_table = mtha_create_uniquing_table([[self path] cStringUsingEncoding:NSUTF8StringEncoding], 256);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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

- (NSString *)path {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"uniquing_table_test"];
}

#if TARGET_IPHONE_SIMULATOR

#else // TARGET_IPHONE_SIMULATOR
- (uint64_t)insert:(vm_address_t *)frames count:(uint32_t)count {
    uint64_t uniqueStackIdentifier = mtha_vm_invalid_stack_id;
    mtha_enter_frames_in_table(uniquing_table, &uniqueStackIdentifier, frames, count);

    if (!mtha_enter_frames_in_table(uniquing_table, &uniqueStackIdentifier, frames, count)) {
        uniquing_table = mtha_expand_uniquing_table(uniquing_table);
        if (uniquing_table) {
            if (!mtha_enter_frames_in_table(uniquing_table, &uniqueStackIdentifier, frames, count))
                return mtha_vm_invalid_stack_id;
        } else {
            return mtha_vm_invalid_stack_id;
        }
    }

    return uniqueStackIdentifier;
}

- (void)testUniquingTableInsert {
    NSInteger beginIndex = 10000000;
    NSInteger totalCount = 10000000;
    NSIndexSet *indexes = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(beginIndex, totalCount)];

    const NSInteger kFramesCount = 10;

    NSMutableArray<NSNumber *> *stackidArr = [NSMutableArray array];
    for (NSInteger i = beginIndex; i < beginIndex + totalCount;) {
        NSUInteger frames[kFramesCount];
        NSRange range = NSMakeRange(i, kFramesCount);
        [indexes getIndexes:frames maxCount:kFramesCount inIndexRange:&range];

        i += kFramesCount;

        uint64_t sid = [self insert:frames count:kFramesCount];
        if (sid == mtha_vm_invalid_stack_id) {
            [self insert:frames count:kFramesCount];
        }
        [stackidArr addObject:@(sid)];
    }

    __weak typeof(self) wself = self;
    [stackidArr enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        __strong typeof(self) self = wself;
        uint64_t sid = [obj longValue];
        NSUInteger frames[kFramesCount];
        uint32_t out_frames_count;
        mtha_unwind_stack_from_table_index(self->uniquing_table, sid, frames, &out_frames_count, kFramesCount);
        XCTAssertEqual(out_frames_count, kFramesCount);
        XCTAssertTrue(frames[0] != 0);
    }];
}

#endif // TARGET_IPHONE_SIMULATOR

@end
