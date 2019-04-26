//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/6
// Created by: EuanC
//


#import "MTHLivingObjectSniffer.h"
#import "MTHLivingObjectInfo.h"
#import "MTHawkeyeLogMacros.h"

#import <sys/time.h>

@implementation MTHLivingObjectShadowPackageInspectResultItem

@end

@implementation MTHLivingObjectShadowPackageInspectResult

@end

/****************************************************************************/
#pragma mark -

@interface MTHLivingObjectSniffer ()

@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *objectClassNameSet;
@property (nonatomic, strong) NSMutableArray<MTHLivingObjectGroupInClass *> *mutableGroups;

@property (nonatomic, strong) dispatch_queue_t snifferQueue;

@property (nonatomic, strong) dispatch_source_t viewShadowPoolSniffTimer;

@property (nonatomic, strong) NSRecursiveLock *viewShadowPoolWaitingSniffLock;
@property (nonatomic, strong) NSHashTable<MTHLivingObjectShadow *> *viewShadowPoolWaitingSniff;

@property (nonatomic, strong) NSHashTable<id<MTHLivingObjectSnifferDelegate>> *delegates;

@end


@implementation MTHLivingObjectSniffer

- (instancetype)init {
    if (self = [super init]) {
        _objectClassNameSet = [[NSMutableOrderedSet alloc] init];
        _mutableGroups = [[NSMutableArray alloc] init];
        _delegates = [NSHashTable weakObjectsHashTable];

        _viewShadowPoolWaitingSniffLock = [[NSRecursiveLock alloc] init];

        _snifferQueue = dispatch_queue_create("com.meitu.hawkeye.living-object-sniffer-queue", DISPATCH_QUEUE_SERIAL);
        _viewShadowPoolSniffTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _snifferQueue);

        dispatch_source_set_timer(_viewShadowPoolSniffTimer, DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_viewShadowPoolSniffTimer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    [self sniffWaitingPoolShadows];
                }
            });
        });
        dispatch_resume(_viewShadowPoolSniffTimer);
    }
    return self;
}

- (void)dealloc {
    if (self.viewShadowPoolSniffTimer) {
        dispatch_source_cancel(self.viewShadowPoolSniffTimer);
        self.viewShadowPoolSniffTimer = nil;
        self.snifferQueue = nil;
    }
}

- (void)syncPerformBlock:(dispatch_block_t)block {
    dispatch_sync(_snifferQueue, block);
}

- (void)asyncPerformBlock:(dispatch_block_t)block {
    dispatch_async(_snifferQueue, block);
}

- (void)addDelegate:(id<MTHLivingObjectSnifferDelegate>)delegate {
    @synchronized(self.delegates) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<MTHLivingObjectSnifferDelegate>)delegate {
    @synchronized(self.delegates) {
        [self.delegates removeObject:delegate];
    }
}

- (void)sniffWillReleasedLivingObjectShadowPackage:(MTHLivingObjectShadowPackage *)shadowPackage
                                  expectReleasedIn:(NSTimeInterval)delayInSeconds
                                       triggerInfo:(nonnull MTHLivingObjectShadowTrigger *)trigger {
    NSAssert([NSThread isMainThread], @"You must use %@ from the main thread only.", NSStringFromClass([self class]));

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#if _InternalMTHLivingObjectSnifferPerformanceTestEnabled
        NSTimeInterval t0 = CFAbsoluteTimeGetCurrent();
#endif

        [self doSniffLivingObjectShadowPackage:shadowPackage
                                   triggerInfo:trigger];

#if _InternalMTHLivingObjectSnifferPerformanceTestEnabled
        printf("[hawkeye][profile] ViewController do sniff cost %.3fms, count %d \n", (CFAbsoluteTimeGetCurrent() - t0) * 1000, shadowPackage.shadows.count);
#endif
    });
}

- (void)sniffLivingViewShadow:(MTHLivingObjectShadow *)shadow {
    [self.viewShadowPoolWaitingSniffLock lock];
    [self.viewShadowPoolWaitingSniff addObject:shadow];
    [self.viewShadowPoolWaitingSniffLock unlock];
}

- (void)sniffWaitingPoolShadows {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSMutableArray<MTHLivingObjectShadow *> *shadowsToSniff = @[].mutableCopy;

    [self.viewShadowPoolWaitingSniffLock lock];
    for (MTHLivingObjectShadow *shadow in self.viewShadowPoolWaitingSniff) {
        if (now - shadow.createAt > 1.5f) {
            [shadowsToSniff addObject:shadow];
        }
    }
    [self.viewShadowPoolWaitingSniffLock unlock];

    __weak __typeof(self) weakSelf = self;
    [self
        asyncExtraceUnexpectedLivingShadowsFrom:[shadowsToSniff copy]
                                     completion:^(NSArray<MTHLivingObjectShadow *> *unexpectedShadows, NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *resultItems) {
                                         if (resultItems.count == 0)
                                             return;

                                         __strong __typeof(weakSelf) strongSelf = weakSelf;
                                         [strongSelf.viewShadowPoolWaitingSniffLock lock];
                                         for (MTHLivingObjectShadow *unexpectedShadow in unexpectedShadows) {
                                             [strongSelf.viewShadowPoolWaitingSniff removeObject:unexpectedShadow];
                                         }
                                         [strongSelf.viewShadowPoolWaitingSniffLock unlock];

                                         MTHLivingObjectShadowPackageInspectResult *result = [[MTHLivingObjectShadowPackageInspectResult alloc] init];
                                         result.items = resultItems.copy;

                                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                                             @synchronized(strongSelf.delegates) {
                                                 for (id<MTHLivingObjectSnifferDelegate> delegate in strongSelf.delegates) {
                                                     [delegate livingObjectSniffer:strongSelf didSniffOutResult:result];
                                                 }
                                             }
                                         });
                                     }];
}

- (void)doSniffLivingObjectShadowPackage:(MTHLivingObjectShadowPackage *)shadowPackage
                             triggerInfo:(MTHLivingObjectShadowTrigger *)trigger {
    NSArray<MTHLivingObjectShadow *> *shadows = shadowPackage.shadows.allObjects;
    __weak __typeof(self) weakSelf = self;
    [self
        asyncExtraceUnexpectedLivingShadowsFrom:shadows
                                     completion:^(NSArray<MTHLivingObjectShadow *> *unexpectedShadows, NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *resultItems) {
                                         if (resultItems.count == 0)
                                             return;

                                         __strong __typeof(weakSelf) strongSelf = weakSelf;

                                         MTHLivingObjectShadowPackageInspectResult *result = [[MTHLivingObjectShadowPackageInspectResult alloc] init];
                                         result.items = resultItems.copy;
                                         result.trigger = trigger;

                                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                                             @synchronized(strongSelf.delegates) {
                                                 for (id<MTHLivingObjectSnifferDelegate> delegate in strongSelf.delegates) {
                                                     [delegate livingObjectSniffer:strongSelf didSniffOutResult:result];
                                                 }
                                             }
                                         });
                                     }];
}

/**
 param: clearlyBoundary:
 as a view instance, it would be check though `sniffLivingViewShadow:` and `sniffWillReleasedLivingObjectShadowPackage:expectReleasedIn:triggerInfo:`,
 when assign `theHodlerIsNotOwner`, we only make mark when it's process though `sniffWillReleased***`,
 the `sniffLivingViewShadow` process was simply ignored.
 */
- (void)asyncExtraceUnexpectedLivingShadowsFrom:(NSArray<MTHLivingObjectShadow *> *)shadowsToSniff
                                     completion:(void (^)(NSArray<MTHLivingObjectShadow *> *, NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *))completion {
    __weak __typeof(self) weakSelf = self;
    [self asyncPerformBlock:^{
        __strong __typeof(weakSelf) self = weakSelf;
        NSMutableArray<MTHLivingObjectShadowPackageInspectResultItem *> *resultItems = @[].mutableCopy;
        NSMutableArray<MTHLivingObjectShadow *> *unexpectShadows = @[].mutableCopy;
        for (MTHLivingObjectShadow *shadow in shadowsToSniff) {
            if (shadow.target == nil || [self.ignoreList containsObject:NSStringFromClass([shadow.target class])]) {
                [unexpectShadows addObject:shadow];
                continue;
            }

            if ([self shouldShadowTargetReleaseButNot:shadow]) {
                MTHLivingObjectInfo *theInstanceInfo = nil;
                MTHLivingObjectGroupInClass *theInstanceInfoGroup = nil;

                [self processingUnexpectedLivingObjectShadow:shadow
                                             getLivingObject:&theInstanceInfo
                                        getLivingObjectGroup:&theInstanceInfoGroup];

                [self updateInspectResultItems:resultItems withLivingObjInfo:theInstanceInfo underGroup:theInstanceInfoGroup];

                [unexpectShadows addObject:shadow];
            }
        }
        completion(unexpectShadows, resultItems);
    }];
}

- (void)updateInspectResultItems:(NSMutableArray<MTHLivingObjectShadowPackageInspectResultItem *> *)resultItems
               withLivingObjInfo:(MTHLivingObjectInfo *)theInstanceInfo
                      underGroup:(MTHLivingObjectGroupInClass *)theInstanceInfoGroup {
    if (!resultItems || !theInstanceInfo || !theInstanceInfoGroup) {
        return;
    }

    MTHLivingObjectShadowPackageInspectResultItem *matchedItem = nil;
    for (MTHLivingObjectShadowPackageInspectResultItem *item in resultItems) {
        if (item.theGroupInClass == theInstanceInfoGroup) {
            matchedItem = item;
            NSMutableArray *temp = matchedItem.livingObjectsNew ? matchedItem.livingObjectsNew.mutableCopy : @[].mutableCopy;
            [temp addObject:theInstanceInfo];
            matchedItem.livingObjectsNew = temp.copy;
            break;
        }
    }

    if (matchedItem == nil) {
        matchedItem = [[MTHLivingObjectShadowPackageInspectResultItem alloc] init];
        matchedItem.livingObjectsNew = @[ theInstanceInfo ];
        matchedItem.theGroupInClass = theInstanceInfoGroup;
        [resultItems addObject:matchedItem];
    }
}

- (BOOL)shouldShadowTargetReleaseButNot:(MTHLivingObjectShadow *)shadow {
    BOOL shouldAlive = [shadow.target mth_shouldObjectAlive];
    if (!shouldAlive && [shadow.light isKindOfClass:[UIViewController class]]) {
        UIViewController *hostVC = (UIViewController *)shadow.light;
        if ([hostVC.view.window isKindOfClass:[UIWindow class]] || hostVC.navigationController != nil || hostVC.presentingViewController != nil) {
            shouldAlive = YES;
        }
    }
    return !shouldAlive;
}

- (void)processingUnexpectedLivingObjectShadow:(MTHLivingObjectShadow *)objShadow
                               getLivingObject:(MTHLivingObjectInfo *_Nullable __autoreleasing *)resultLivingObj
                          getLivingObjectGroup:(MTHLivingObjectGroupInClass *_Nullable __autoreleasing *)resultLivingObjGroup {
    if (!objShadow)
        return;

    NSString *className = NSStringFromClass([objShadow.target class]);
    if (className == nil) {
        return;
    }

    __weak typeof(self) weakSelf = self;

    MTHLivingObjectGroupInClass *group = nil;
    if ([self.objectClassNameSet containsObject:className]) {
        NSUInteger index = [self.objectClassNameSet indexOfObject:className];
        group = self.mutableGroups[index];

        __weak MTHLivingObjectGroupInClass *weakGroup = group;
        [group
            addMayLeakedInstance:objShadow
                      completion:^(MTHLivingObjectInfo *theAliveInstance) {
                          __strong typeof(weakSelf) strongSelf = weakSelf;
                          __strong MTHLivingObjectGroupInClass *strongGroup = weakGroup;

                          if (strongSelf && strongGroup && !theAliveInstance.theHodlerIsNotOwner) {
                              // bubble up
                              [strongSelf.mutableGroups removeObjectAtIndex:index];
                              [strongSelf.mutableGroups insertObject:strongGroup atIndex:0];
                              [strongSelf.objectClassNameSet removeObject:className];
                              [strongSelf.objectClassNameSet insertObject:className atIndex:0];

                              *resultLivingObj = theAliveInstance;
                              *resultLivingObjGroup = strongGroup;
                          }
                      }];
    } else {
        [self.objectClassNameSet insertObject:className atIndex:0];
        group = [[MTHLivingObjectGroupInClass alloc] init];

        __weak MTHLivingObjectGroupInClass *weakGroup = group;
        [group
            addMayLeakedInstance:objShadow
                      completion:^(MTHLivingObjectInfo *theAliveInstance) {
                          __strong typeof(weakSelf) strongSelf = weakSelf;
                          __strong MTHLivingObjectGroupInClass *strongGroup = weakGroup;

                          if (strongSelf && strongGroup && !theAliveInstance.theHodlerIsNotOwner) {
                              [strongSelf.mutableGroups insertObject:strongGroup atIndex:0];

                              *resultLivingObj = theAliveInstance;
                              *resultLivingObjGroup = strongGroup;
                          }
                      }];
    }
}

// MARK: - getter
- (NSArray<MTHLivingObjectGroupInClass *> *)livingObjectGroupsInClass {
    NSMutableArray<MTHLivingObjectGroupInClass *> *list = @[].mutableCopy;
    __weak typeof(self) weakSelf = self;
    [self syncPerformBlock:^{
        for (MTHLivingObjectGroupInClass *group in weakSelf.mutableGroups) {
            if (group.aliveInstanceCount > 0) {
                [list addObject:group];
            }
        }
    }];
    return [list copy];
}

- (NSMutableArray<NSString *> *)ignoreList {
    if (!_ignoreList) {
        _ignoreList = [NSMutableArray array];
    }
    return _ignoreList;
}

- (NSHashTable<MTHLivingObjectShadow *> *)viewShadowPoolWaitingSniff {
    if (!_viewShadowPoolWaitingSniff) {
        _viewShadowPoolWaitingSniff = [NSHashTable weakObjectsHashTable];
    }
    return _viewShadowPoolWaitingSniff;
}

@end
