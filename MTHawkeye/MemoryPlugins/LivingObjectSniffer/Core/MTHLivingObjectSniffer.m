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

#import <pthread/pthread.h>
#import <sys/time.h>

@implementation MTHLivingObjectShadowPackageInspectResultItem

@end

@implementation MTHLivingObjectShadowPackageInspectResult

@end

/****************************************************************************/
#pragma mark -

@interface MTHLivingObjectSniffer () {
    pthread_mutex_t _groups_mutex;
}

@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *objectClassNameSet;
@property (nonatomic, strong) NSMutableArray<MTHLivingObjectGroupInClass *> *mutableGroups;

@property (nonatomic, strong) dispatch_source_t viewShadowPoolSniffTimer;

@property (nonatomic, strong) NSRecursiveLock *viewShadowPoolWaitingSniffLock;
@property (nonatomic, strong) NSHashTable<MTHLivingObjectShadow *> *viewShadowPoolWaitingSniff;

@property (nonatomic, strong) NSHashTable<id<MTHLivingObjectSnifferDelegate>> *delegates;

@end


@implementation MTHLivingObjectSniffer

- (instancetype)init {
    if ((self = [super init])) {
        _objectClassNameSet = [[NSMutableOrderedSet alloc] init];
        _mutableGroups = [[NSMutableArray alloc] init];
        _delegates = [NSHashTable weakObjectsHashTable];

        _viewShadowPoolWaitingSniffLock = [[NSRecursiveLock alloc] init];

        pthread_mutex_init(&_groups_mutex, NULL);

        _viewShadowPoolSniffTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_timer(_viewShadowPoolSniffTimer, DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_viewShadowPoolSniffTimer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    [weakSelf sniffWaitingPoolShadows];
                }
            });
        });
        dispatch_resume(_viewShadowPoolSniffTimer);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_groups_mutex);

    if (self.viewShadowPoolSniffTimer) {
        dispatch_source_cancel(self.viewShadowPoolSniffTimer);
        self.viewShadowPoolSniffTimer = nil;
    }
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
        extraceUnexpectedLivingShadowsFrom:[shadowsToSniff copy]
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

                                    @synchronized(strongSelf.delegates) {
                                        for (id<MTHLivingObjectSnifferDelegate> delegate in strongSelf.delegates) {
                                            [delegate livingObjectSniffer:strongSelf didSniffOutResult:result];
                                        }
                                    }
                                }];
}

- (void)doSniffLivingObjectShadowPackage:(MTHLivingObjectShadowPackage *)shadowPackage
                             triggerInfo:(MTHLivingObjectShadowTrigger *)trigger {
    NSArray<MTHLivingObjectShadow *> *shadows = shadowPackage.shadows.allObjects;
    __weak __typeof(self) weakSelf = self;
    [self extraceUnexpectedLivingShadowsFrom:shadows
                                  completion:^(NSArray<MTHLivingObjectShadow *> *unexpectedShadows, NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *resultItems) {
                                      if (resultItems.count == 0)
                                          return;

                                      __strong __typeof(weakSelf) strongSelf = weakSelf;

                                      MTHLivingObjectShadowPackageInspectResult *result = [[MTHLivingObjectShadowPackageInspectResult alloc] init];
                                      result.items = resultItems.copy;
                                      result.trigger = trigger;

                                      @synchronized(strongSelf.delegates) {
                                          for (id<MTHLivingObjectSnifferDelegate> delegate in strongSelf.delegates) {
                                              [delegate livingObjectSniffer:strongSelf didSniffOutResult:result];
                                          }
                                      }
                                  }];
}

/**
 param: clearlyBoundary:
 as a view instance, it would be check though `sniffLivingViewShadow:` and `sniffWillReleasedLivingObjectShadowPackage:expectReleasedIn:triggerInfo:`,
 when assign `theHodlerIsNotOwner`, we only make mark when it's process though `sniffWillReleased***`,
 the `sniffLivingViewShadow` process was simply ignored.
 */
- (void)extraceUnexpectedLivingShadowsFrom:(NSArray<MTHLivingObjectShadow *> *)shadowsToSniff
                                completion:(void (^)(NSArray<MTHLivingObjectShadow *> *, NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *))completion {
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
    if (completion)
        completion(unexpectShadows, resultItems);
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

        pthread_mutex_lock(&_groups_mutex);
        group = self.mutableGroups[index];
        pthread_mutex_unlock(&_groups_mutex);

        __weak MTHLivingObjectGroupInClass *weakGroup = group;
        [group
            addMayLeakedInstance:objShadow
                      completion:^(MTHLivingObjectInfo *theAliveInstance) {
                          __strong typeof(weakSelf) strongSelf = weakSelf;
                          __strong MTHLivingObjectGroupInClass *strongGroup = weakGroup;

                          if (strongSelf && strongGroup && !theAliveInstance.theHodlerIsNotOwner) {
                              // bubble up
                              pthread_mutex_lock(&(strongSelf->_groups_mutex));

                              [strongSelf.mutableGroups removeObjectAtIndex:index];
                              [strongSelf.mutableGroups insertObject:strongGroup atIndex:0];
                              [strongSelf.objectClassNameSet removeObject:className];
                              [strongSelf.objectClassNameSet insertObject:className atIndex:0];

                              pthread_mutex_unlock(&(strongSelf->_groups_mutex));

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
                              pthread_mutex_lock(&(strongSelf->_groups_mutex));
                              [strongSelf.mutableGroups insertObject:strongGroup atIndex:0];
                              pthread_mutex_unlock(&(strongSelf->_groups_mutex));

                              *resultLivingObj = theAliveInstance;
                              *resultLivingObjGroup = strongGroup;
                          }
                      }];
    }
}

// MARK: - getter
- (NSArray<MTHLivingObjectGroupInClass *> *)livingObjectGroupsInClass {
    NSMutableArray<MTHLivingObjectGroupInClass *> *result = @[].mutableCopy;

    pthread_mutex_lock(&_groups_mutex);
    NSArray<MTHLivingObjectGroupInClass *> *groups = [self.mutableGroups copy];
    pthread_mutex_unlock(&_groups_mutex);

    for (NSInteger i = 0; i < groups.count; ++i) {
        MTHLivingObjectGroupInClass *group = groups[i];
        if (group.aliveInstanceCount > 0) {
            [result addObject:group];
        }
    }
    return [result copy];
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
