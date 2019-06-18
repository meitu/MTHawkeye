//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/6/29
// Created by: YWH
//


#import "MTHFPSTrace.h"

#import <sys/time.h>

#import <MTHawkeye/MTHawkeyeHooking.h>
#import <MTHawkeye/MTHawkeyeSignPosts.h>
#import <MTHawkeye/MTHawkeyeWeakProxy.h>


@interface MTHFPSTrace ()

@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) NSInteger fpsValue;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) BOOL gpuImageViewFPSEnable;
@property (nonatomic, assign) BOOL gpuImageViewDisplaying;
@property (nonatomic, assign) NSInteger gpuImageFPSValue;

@property (nonatomic, strong) NSHashTable<id<MTHFPSTraceDelegate>> *delegates;

@end


@implementation MTHFPSTrace {
    NSUInteger _count;        // 记录一定时间内总共刷新了多少帧
    NSTimeInterval _lastTime; // 起始记录的时间戳
}

- (void)dealloc {
    [_displayLink invalidate];
}

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (CADisplayLink *)displayLink {
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:[MTHawkeyeWeakProxy proxyWithTarget:self] selector:@selector(tick:)];
    }
    return _displayLink;
}

// MARK: - delegates
- (void)addDelegate:(id<MTHFPSTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<MTHFPSTraceDelegate>)delegate {
    if (!delegate) {
        return;
    }
    @synchronized(self.delegates) {
        [self.delegates removeObject:delegate];
    }
}

// MARK: -
- (void)start {
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.isRunning = YES;

    self.gpuImageViewDisplaying = NO;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self trackGPUImagePresentUnderClass:NSClassFromString(@"GPUImageView")];
        [self trackGPUImagePresentUnderClass:NSClassFromString(@"MTCameraGPUImageView")];
    });
}

- (void)trackGPUImagePresentUnderClass:(Class)cls {
    SEL sel1 = NSSelectorFromString(@"createDisplayFramebuffer");
    if (cls && sel1) {
        SEL swizzledSel = [MTHawkeyeHooking swizzledSelectorForSelector:sel1];
        void (^swizzleBlock)(id) = ^void(id obj) {
            ((void (*)(id, SEL))objc_msgSend)(obj, swizzledSel);
            [self gpuImageViewStartDisplay];
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:sel1 onClass:cls withBlock:swizzleBlock swizzledSelector:swizzledSel];

        self.gpuImageViewFPSEnable = YES;
    }

    SEL sel2 = NSSelectorFromString(@"destroyDisplayFramebuffer");
    if (cls && sel2) {
        SEL swizzledSel = [MTHawkeyeHooking swizzledSelectorForSelector:sel2];
        void (^swizzleBlock)(id) = ^void(id obj) {
            ((void (*)(id, SEL))objc_msgSend)(obj, swizzledSel);
            [self gpuImageViewEndDisplay];
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:sel2 onClass:cls withBlock:swizzleBlock swizzledSelector:swizzledSel];

        self.gpuImageViewFPSEnable = YES;
    }

    SEL sel3 = NSSelectorFromString(@"presentFramebuffer");
    if (cls && sel3) {
        SEL swizzledSel = [MTHawkeyeHooking swizzledSelectorForSelector:sel3];
        void (^swizzleBlock)(id) = ^void(id obj) {
            ((void (*)(id, SEL))objc_msgSend)(obj, swizzledSel);
            [self tickGPUImagePresent];
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:sel3 onClass:cls withBlock:swizzleBlock swizzledSelector:swizzledSel];

        self.gpuImageViewFPSEnable = YES;
    }
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.isRunning = NO;
}

// MARK: - tick
- (void)tick:(CADisplayLink *)link {
    static NSInteger signpostId = 0;
    if (_lastTime < DBL_EPSILON) {
        _lastTime = link.timestamp;
        MTHSignpostStartCustom(999, signpostId, 0);
        return;
    }

    MTHSignpostEndCustom(999, signpostId, 0, 2);
    signpostId++;
    MTHSignpostStartCustom(999, signpostId, 0);

    _count++;
    NSTimeInterval delta = link.timestamp - _lastTime; // 刷新间隔
    if (delta < 1) return;                             // 计算一秒刷新多少帧，小于1s直接返回
    _lastTime = link.timestamp;
    float fps = _count / delta;
    _count = 0;
    int newFPS = (int)round(fps);

    if (_fpsValue != newFPS) {
        [self.delegates.allObjects enumerateObjectsUsingBlock:^(id<MTHFPSTraceDelegate> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj respondsToSelector:@selector(fpsValueDidChanged:)]) {
                [obj fpsValueDidChanged:newFPS];
            }
        }];
    }
    _fpsValue = newFPS;
}

- (void)tickGPUImagePresent {
    static struct timeval t0;
    static NSInteger count = 0;
    static NSInteger signpostId = 0;
    if (t0.tv_usec == 0) {
        gettimeofday(&t0, NULL);
        MTHSignpostStartCustom(998, signpostId, 0);
        return;
    }

    MTHSignpostEndCustom(998, signpostId, 0, 3);
    signpostId++;
    MTHSignpostStartCustom(998, signpostId, 0);

    count++;

    struct timeval t1;
    gettimeofday(&t1, NULL);
    double ms = (double)(t1.tv_sec - t0.tv_sec) * 1e3 + (double)(t1.tv_usec - t0.tv_usec) * 1e-3;
    if (ms < 1000.f) return;

    if (ms > 0) {
        NSInteger newGPUImageFPS = (NSInteger)round(count * 1000.f / ms);
        if (newGPUImageFPS != self.gpuImageFPSValue) {
            [self.delegates.allObjects enumerateObjectsUsingBlock:^(id<MTHFPSTraceDelegate> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if ([obj respondsToSelector:@selector(gpuImageFPSValueDidChanged:)]) {
                    [obj gpuImageFPSValueDidChanged:newGPUImageFPS];
                }
            }];
        }
        self.gpuImageFPSValue = newGPUImageFPS;
    }

    t0 = t1;
    count = 0;
}

- (void)gpuImageViewStartDisplay {
    self.gpuImageViewDisplaying = YES;
    self.gpuImageFPSValue = 0.f;

    [self notifyGPUImagePresentStatusChanged];
}

- (void)gpuImageViewEndDisplay {
    self.gpuImageViewDisplaying = NO;
    self.gpuImageFPSValue = 0.f;

    [self notifyGPUImagePresentStatusChanged];
}

- (void)notifyGPUImagePresentStatusChanged {
    [self.delegates.allObjects enumerateObjectsUsingBlock:^(id<MTHFPSTraceDelegate> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([obj respondsToSelector:@selector(gpuImageDisplayingChanged:)]) {
            [obj gpuImageDisplayingChanged:self.gpuImageViewDisplaying];
        }
        if ([obj respondsToSelector:@selector(gpuImageFPSValueDidChanged:)]) {
            [obj gpuImageFPSValueDidChanged:self.gpuImageFPSValue];
        }
    }];
}

// MARK: - getter
- (NSHashTable<id<MTHFPSTraceDelegate>> *)delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable weakObjectsHashTable];
    }
    return _delegates;
}

@end
