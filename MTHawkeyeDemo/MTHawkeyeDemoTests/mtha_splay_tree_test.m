//
//  mtha_splay_tree_test.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 2018/11/1.
//  Copyright © 2018 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <malloc/malloc.h>
#import "mtha_inner_allocate.h"
#import "mtha_splay_tree.h"

@interface mtha_splay_tree_test : XCTestCase {
    mtha_splay_tree *tree;
    malloc_zone_t *zone;
}

@end

@implementation mtha_splay_tree_test

- (NSString *)path {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"splay_tree_test"];
}

- (void)setUp {
    zone = malloc_default_zone();
    mtha_setup_hawkeye_malloc_zone(zone);

    tree = mtha_splay_tree_create_on_mmapfile(10, [[self path] cStringUsingEncoding:NSUTF8StringEncoding]);
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

- (void)testSplayTreeExpand {
    NSInteger count = 1000000;
    for (NSInteger i = 1; i <= count; ++i) {
        if (!mtha_splay_tree_insert(tree, i, i, i)) {
            tree = mtha_expand_splay_tree(tree);
            bool result = mtha_splay_tree_insert(tree, i, i, i);
            XCTAssertTrue(result);
        }
    }

    NSMutableSet *r_cs = [NSMutableSet set];
    NSMutableSet *r_sf = [NSMutableSet set];
    for (int i = 0; i <= tree->max_index; ++i) {
        mtha_splay_tree_node node = tree->node[i];
        if (node.category_and_size != 0) {
            [r_cs addObject:@(node.category_and_size)];
            [r_sf addObject:@(node.stackid_and_flags)];
        }
    }

    XCTAssert(r_cs.count == count);
    XCTAssert(r_sf.count == count);

    for (NSInteger i = 1; i <= count; ++i) {
        XCTAssertTrue([r_cs containsObject:@(i)]);
        XCTAssertTrue([r_sf containsObject:@(i)]);
    }

    for (NSInteger i = 1; i <= count; i += 2) {
        mtha_splay_tree_delete(tree, i);
    }

    r_cs = [NSMutableSet set];
    r_sf = [NSMutableSet set];
    for (int i = 0; i <= tree->max_index; ++i) {
        mtha_splay_tree_node node = tree->node[i];
        if (node.category_and_size != 0) {
            [r_cs addObject:@(node.category_and_size)];
            [r_sf addObject:@(node.stackid_and_flags)];
        }
    }
    XCTAssert(r_cs.count == count / 2);
    XCTAssert(r_sf.count == count / 2);
}

@end
