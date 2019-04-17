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


#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <vector>

NS_ASSUME_NONNULL_BEGIN

struct MTH_CPUTraceThreadIdAndUsage {
    thread_t traceThread;
    double cpuUsage;
};

class MTH_CPUTraceStackFramesNode
{
  public:
    uintptr_t stackframeAddr = 0;
    uint32_t calledCount = 0;

    std::vector<MTH_CPUTraceStackFramesNode *> children;

  public:
    MTH_CPUTraceStackFramesNode(){};
    ~MTH_CPUTraceStackFramesNode(){};

    void resetSubCalls();
    inline bool isEquralToStackFrameNode(MTH_CPUTraceStackFramesNode *node) {
        return this->stackframeAddr == node->stackframeAddr;
    };

    MTH_CPUTraceStackFramesNode *addSubCallNode(MTH_CPUTraceStackFramesNode *node);

    NSArray<NSDictionary *> *json();
    NSString *jsonString();
};


@interface MTHCPUTraceHighLoadRecord : NSObject

@property (nonatomic, assign) CFAbsoluteTime startAt; /**< The cpu high load record start at. */
@property (nonatomic, assign) CFAbsoluteTime lasting; /**< How long the cpu high load lasting */
@property (nonatomic, assign) float averageCPUUsage;  /**< The average cpu usage during the high load */

@end

NS_ASSUME_NONNULL_END
