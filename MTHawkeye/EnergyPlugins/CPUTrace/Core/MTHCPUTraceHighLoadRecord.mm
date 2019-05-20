//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/18
// Created by: Zed
//


#import "MTHCPUTraceHighLoadRecord.h"
#import <MTHawkeye/MTHawkeyeLogMacros.h>


void MTH_CPUTraceStackFramesNode::resetSubCalls(void) {
    if (this->children.size()) {
        for (auto tmp : this->children) {
            tmp->resetSubCalls();
            delete tmp;
        }
        this->children.clear();
    }
}

MTH_CPUTraceStackFramesNode *MTH_CPUTraceStackFramesNode::addSubCallNode(MTH_CPUTraceStackFramesNode *node) {
    bool isExist = false;
    MTH_CPUTraceStackFramesNode *curNode = NULL;
    if (this->children.size()) {
        for (auto item : this->children) {
            if (item->isEquralToStackFrameNode(node)) {
                item->calledCount++;
                node->calledCount = item->calledCount;
                curNode = item;
                isExist = true;
                break;
            }
        }
    }

    if (!isExist) {
        curNode = node;
        node->calledCount = 1;
        this->children.push_back(node);
    }

    return curNode;
}

static NSDictionary *convertStackFramesSampleIntoDictionaryWithTotalSampleCount(MTH_CPUTraceStackFramesNode *node, uint32_t totalSampleCount) {
    NSMutableDictionary *dic = @{}.mutableCopy;
    dic[@"frame"] = [NSString stringWithFormat:@"%p", (void *)node->stackframeAddr];
    dic[@"count"] = @(node->calledCount);
    dic[@"proportion"] = @(node->calledCount / (double)totalSampleCount);
    NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:node->children.size() + 1];
    for (auto childNode : node->children) {
        [children addObject:convertStackFramesSampleIntoDictionaryWithTotalSampleCount(childNode, totalSampleCount)];
    }
    if (children.count > 0)
        dic[@"children"] = [children copy];

    return [dic copy];
}

NSArray<NSDictionary *> *MTH_CPUTraceStackFramesNode::json() {
    if (this->children.size() == 0)
        return nil;

    uint32_t totalSampleCount = 0;
    for (auto tmp : this->children) {
        totalSampleCount += tmp->calledCount;
    }

    NSMutableArray *rootLevelNodes = [NSMutableArray array];
    for (auto note : this->children) {
        [rootLevelNodes addObject:convertStackFramesSampleIntoDictionaryWithTotalSampleCount(note, totalSampleCount)];
    }
    return [rootLevelNodes copy];
}

NSString *MTH_CPUTraceStackFramesNode::jsonString() {
    NSArray *rootLevelNodes = this->json();
    if (rootLevelNodes.count == 0)
        return nil;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:rootLevelNodes options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn("[hawkeye][cputrace] persist cputrace failed: %@", error.localizedDescription);
    }

    NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return value;
}

// MARK: -
@implementation MTHCPUTraceHighLoadRecord

- (instancetype)init {
    if ((self = [super init])) {
    }
    return self;
}

@end
