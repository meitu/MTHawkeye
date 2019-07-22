//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 28/08/2017
// Created by: EuanC
//


#import "MTHNetworkObserver.h"

#import <sys/time.h>

#import "MTHNetworkRecorder.h"
#import "MTHNetworkTransaction.h"
#import "MTHURLConnectionDelegateProxy.h"
#import "MTHURLSessionDelegateProxy.h"
#import "MTHawkeyeHooking.h"
#import "MTHawkeyeLogMacros.h"


typedef void (^NSURLSessionAsyncCompletion)(id fileURLOrData, NSURLResponse *response, NSError *error);


@interface MTHawkeyeNetworkInternalRequestState : NSObject

@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic, strong) NSMutableData *dataAccumulator;

@end

@implementation MTHawkeyeNetworkInternalRequestState

@end

// MARK: -

@interface MTHNetworkObserver (NSURLConnectionMTHHelpers)

- (void)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data impl:(id)impl;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error impl:(id)impl;
- (void)connectionWillCancel:(NSURLConnection *)connection;

@end


@interface MTHNetworkObserver (NSURLSessionTaskMTHHelpers)

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics impl:(id)impl NS_AVAILABLE_IOS(10_0);
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location data:(NSData *)data impl:(id)impl;

- (void)URLSessionTaskWillResume:(NSURLSessionTask *)task;
- (void)recordSessionAPIUsageWithRequestID:(NSString *)requestID session:(NSURLSession *)session task:(NSURLSessionTask *)task;

@end


// MARK: -

@interface MTHNetworkObserver ()

@property (nonatomic, strong) NSMutableDictionary *requestStatesForRequestIDs;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

static BOOL networkObserverEnabled = NO;

@implementation MTHNetworkObserver

+ (void)setEnabled:(BOOL)enabeld {
    networkObserverEnabled = enabeld;
    if (networkObserverEnabled) {
        [self injectIntoAllNSURLConnectionDelegateClass];
    }
}

+ (BOOL)isEnabled {
    return networkObserverEnabled;
}

// MARK: Statics
+ (instancetype)sharedObserver {
    static id sharedObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObserver = [[[self class] alloc] init];
    });
    return sharedObserver;
}

+ (NSString *)nextRequestID {
    return [[NSUUID UUID] UUIDString];
}

// MARK: - Injection

+ (void)injectIntoAllNSURLConnectionDelegateClass {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // NSURLConnection inject
        [self injectIntoNSURLConnectionCreator];
        [self injectIntoNSURLConnectionCancel];
        [self injectIntoNSURLConnectionAsynchronousClassMethod];
        [self injectIntoNSURLConnectionSynchronousClassMethod];

        // NSURLSession inject
        [self injectIntoURLSessionTaskCreator];
        [self injectIntoNSURLSessionTaskResume];
        [self injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods];
        [self injectIntoNSURLSessionAsyncUploadTaskMethods];

        // improve me: Add network observer test code, make sure the new system has the expected flow
    });
}

// MARK: URLConnectionDelegate & URLSessionDelegate Inject

+ (void)injectIntoNSURLConnectionCreator {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MTHNetworkObserver *observer = [self sharedObserver];

        Class metaClass = objc_getMetaClass(class_getName([NSURLConnection class]));
        SEL selector = @selector(connectionWithRequest:delegate:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

        NSURLConnection * (^creatorSwizzleBlock)(Class, NSURLRequest *request, id<NSURLConnectionDelegate> delegate) = ^NSURLConnection *(Class slf, NSURLRequest *request, id<NSURLConnectionDelegate> delegate) {
            id replacedDelegate = nil;
            MTHURLConnectionDelegateProxy *delegateProxy = [[MTHURLConnectionDelegateProxy alloc] initWithOriginalDelegate:delegate observer:observer];
            replacedDelegate = delegateProxy;
            NSURLConnection *connection = ((id(*)(id, SEL, NSURLRequest *, id))objc_msgSend)(slf, swizzledSelector, request, replacedDelegate);
            return connection;
        };

        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:metaClass withBlock:creatorSwizzleBlock swizzledSelector:swizzledSelector];

        Class class = [NSURLConnection class];
        SEL initSelector = @selector(initWithRequest:delegate:startImmediately:);
        SEL swizzledInitSelector = [MTHawkeyeHooking swizzledSelectorForSelector:initSelector];

        NSURLConnection * (^creatorInitSwizzleBlock)(Class, NSURLRequest *request, id<NSURLConnectionDelegate> delegate, BOOL startImmediately) = ^NSURLConnection *(Class slf, NSURLRequest *request, id<NSURLConnectionDelegate> delegate, BOOL startImmediately) {
            id replacedDelegate = nil;
            if (TRUE) {
                MTHURLConnectionDelegateProxy *delegateProxy = [[MTHURLConnectionDelegateProxy alloc] initWithOriginalDelegate:delegate observer:observer];
                replacedDelegate = delegateProxy;
            } else {
                replacedDelegate = delegate;
            }
            NSURLConnection *connection = ((id(*)(id, SEL, NSURLRequest *, id, BOOL))objc_msgSend)(slf, swizzledInitSelector, request, replacedDelegate, startImmediately);
            return connection;
        };

        [MTHawkeyeHooking replaceImplementationOfKnownSelector:initSelector onClass:class withBlock:creatorInitSwizzleBlock swizzledSelector:swizzledInitSelector];
    });

#pragma clang diagnostic pop
}

+ (void)injectIntoURLSessionTaskCreator {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wunused-variable"

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MTHNetworkObserver *observer = [self sharedObserver];

        Class class = objc_getMetaClass(class_getName([NSURLSession class]));
        SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

        NSURLSession * (^creatorSwizzleBlock)(Class, NSURLSessionConfiguration *, id<NSURLSessionDelegate>, NSOperationQueue *) = ^NSURLSession *(Class slf, NSURLSessionConfiguration *cfg, id<NSURLSessionDelegate> delegate, NSOperationQueue *queue) {
            id replacedDelegate = nil;
            MTHURLSessionDelegateProxy *delegateProxy = [[MTHURLSessionDelegateProxy alloc] initWithOriginalDelegate:delegate observer:observer];
            replacedDelegate = delegateProxy;
            NSURLSession *session = ((id(*)(id, SEL, NSURLSessionConfiguration *, id, NSOperationQueue *))objc_msgSend)(slf, swizzledSelector, cfg, replacedDelegate, queue);
            return session;
        };

        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:creatorSwizzleBlock swizzledSelector:swizzledSelector];
    });

#pragma clang diagnostic pop
}

+ (void)injectIntoNSURLConnectionCancel {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURLConnection class];
        SEL selector = @selector(cancel);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];
        Method originalCancel = class_getInstanceMethod(NSURLConnection.class, selector);
        void (^swizzleBlock)(NSURLConnection *) = ^(NSURLConnection *slf) {
            [[MTHNetworkObserver sharedObserver] connectionWillCancel:slf];
            ((void (*)(id, SEL))objc_msgSend)(slf, swizzledSelector);
        };
        IMP cancelImpl = imp_implementationWithBlock(swizzleBlock);
        class_addMethod(class, swizzledSelector, cancelImpl, method_getTypeEncoding(originalCancel));
        Method newCancel = class_getInstanceMethod(class, swizzledSelector);
        method_exchangeImplementations(originalCancel, newCancel);
    });
}

+ (void)injectIntoNSURLSessionTaskResume {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (NSClassFromString(@"NSURLSessionTask")) {
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
            NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop
            Class currentClass = [localDataTask class];

            SEL selector = @selector(resume);
            SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];
            void (^swizzleBlock)(NSURLSessionTask *) = ^(NSURLSessionTask *slf) {
                [[MTHNetworkObserver sharedObserver] URLSessionTaskWillResume:slf];
                ((void (*)(id, SEL))objc_msgSend)(slf, swizzledSelector);
            };
            IMP hawkeyeResumeIMP = imp_implementationWithBlock(swizzleBlock);

            while (class_getInstanceMethod(currentClass, @selector(resume))) {
                Class superClass = [currentClass superclass];
                IMP classResumeIMP = method_getImplementation(class_getInstanceMethod(currentClass, @selector(resume)));
                IMP superclassResumeIMP = method_getImplementation(class_getInstanceMethod(superClass, @selector(resume)));

                // only swizzling the up most (some child will invoke [super resume]).
                if (classResumeIMP != superclassResumeIMP && hawkeyeResumeIMP != classResumeIMP) {
                    Method originalResume = class_getInstanceMethod(currentClass, selector);
                    if (class_addMethod(currentClass, swizzledSelector, hawkeyeResumeIMP, method_getTypeEncoding(originalResume))) {
                        Method newResume = class_getInstanceMethod(currentClass, swizzledSelector);
                        method_exchangeImplementations(originalResume, newResume);
                    } else {
                        MTHLogWarn(@"failed add %@ to %@", NSStringFromSelector(swizzledSelector), NSStringFromClass(currentClass));
                    }
                }

                currentClass = [currentClass superclass];
            }

            [localDataTask cancel];
            [session finishTasksAndInvalidate];
        }
    });
}

+ (void)injectIntoNSURLConnectionAsynchronousClassMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = objc_getMetaClass(class_getName([NSURLConnection class]));
        SEL selector = @selector(sendAsynchronousRequest:queue:completionHandler:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

        typedef void (^NSURLConnectionAsyncCompletion)(NSURLResponse *response, NSData *data, NSError *connectionError);

        void (^asyncSwizzleBlock)(Class, NSURLRequest *, NSOperationQueue *, NSURLConnectionAsyncCompletion) = ^(Class slf, NSURLRequest *request, NSOperationQueue *queue, NSURLConnectionAsyncCompletion completion) {
            if ([MTHNetworkObserver isEnabled]) {
                NSString *requestID = [self nextRequestID];
                [[MTHNetworkRecorder defaultRecorder] recordRequestWillBeSentWithRequestID:requestID request:request redirectResponse:nil];
                NSString *mechanism = [self mechansimFromClassMethod:selector onClass:class];
                [[MTHNetworkRecorder defaultRecorder] recordMechanism:mechanism forRequestID:requestID];
                NSURLConnectionAsyncCompletion completionWrapper = ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                    [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:response];
                    [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:[data length]];

                    // Call through to the original completion handler
                    if (completion) {
                        completion(response, data, connectionError);
                    }

                    if (connectionError) {
                        [[MTHNetworkRecorder defaultRecorder] recordLoadingFailedWithRequestID:requestID error:connectionError];
                    } else {
                        [[MTHNetworkRecorder defaultRecorder] recordLoadingFinishedWithRequestID:requestID responseBody:data];
                    }
                };
                ((void (*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzledSelector, request, queue, completionWrapper);
            } else {
                ((void (*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzledSelector, request, queue, completion);
            }
        };

        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:asyncSwizzleBlock swizzledSelector:swizzledSelector];
    });
}

+ (void)injectIntoNSURLConnectionSynchronousClassMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = objc_getMetaClass(class_getName([NSURLConnection class]));
        SEL selector = @selector(sendSynchronousRequest:returningResponse:error:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

        NSData * (^syncSwizzleBlock)(Class, NSURLRequest *, NSURLResponse **, NSError **) = ^NSData *(Class slf, NSURLRequest *request, NSURLResponse **response, NSError **error) {
            NSData *data = nil;
            if ([MTHNetworkObserver isEnabled]) {
                NSString *requestID = [self nextRequestID];
                [[MTHNetworkRecorder defaultRecorder] recordRequestWillBeSentWithRequestID:requestID request:request redirectResponse:nil];
                NSString *mechanism = [self mechansimFromClassMethod:selector onClass:class];
                [[MTHNetworkRecorder defaultRecorder] recordMechanism:mechanism forRequestID:requestID];
                NSError *temporaryError = nil;
                NSURLResponse *temporaryResponse = nil;
                data = ((id(*)(id, SEL, id, NSURLResponse **, NSError **))objc_msgSend)(slf, swizzledSelector, request, &temporaryResponse, &temporaryError);
                [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:temporaryResponse];
                [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:[data length]];
                if (temporaryError) {
                    [[MTHNetworkRecorder defaultRecorder] recordLoadingFailedWithRequestID:requestID error:temporaryError];
                } else {
                    [[MTHNetworkRecorder defaultRecorder] recordLoadingFinishedWithRequestID:requestID responseBody:data];
                }
                if (error) {
                    *error = temporaryError;
                }
                if (response) {
                    *response = temporaryResponse;
                }
            } else {
                data = ((id(*)(id, SEL, id, NSURLResponse **, NSError **))objc_msgSend)(slf, swizzledSelector, request, response, error);
            }

            return data;
        };

        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:syncSwizzleBlock swizzledSelector:swizzledSelector];
    });
}

+ (void)injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURLSession class];

        // The method signatures here are close enough that we can use the same logic to inject into all of them.
        const SEL selectors[] = {
            @selector(dataTaskWithRequest:completionHandler:),
            @selector(dataTaskWithURL:completionHandler:),
            @selector(downloadTaskWithRequest:completionHandler:),
            @selector(downloadTaskWithResumeData:completionHandler:),
            @selector(downloadTaskWithURL:completionHandler:)
        };

        const int numSelectors = sizeof(selectors) / sizeof(SEL);

        for (int selectorIndex = 0; selectorIndex < numSelectors; selectorIndex++) {
            SEL selector = selectors[selectorIndex];
            SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

            if ([MTHawkeyeHooking instanceRespondsButDoesNotImplementSelector:selector onClass:class]) {
                // iOS 7 does not implement these methods on NSURLSession. We actually want to
                // swizzle __NSCFURLSession, which we can get from the class of the shared session
                class = [[NSURLSession sharedSession] class];
            }

            NSURLSessionTask * (^asyncDataOrDownloadSwizzleBlock)(Class, id, NSURLSessionAsyncCompletion) = ^NSURLSessionTask *(Class slf, id argument, NSURLSessionAsyncCompletion completion) {
                NSURLSessionTask *task = nil;
                // If completion block was not provided sender expect to receive delegated methods or does not
                // interested in callback at all. In this case we should just call original method implementation
                // with nil completion block.
                if ([MTHNetworkObserver isEnabled] && completion) {
                    NSString *requestID = [self nextRequestID];
                    NSString *mechanism = [self mechansimFromClassMethod:selector onClass:class];
                    NSURLSessionAsyncCompletion completionWrapper = [self
                        asyncCompletionWrapperForRequestID:requestID
                                                 mechanism:mechanism
                                                completion:^(id fileURLOrData, NSURLResponse *response, NSError *error) {
                                                    // API Usage Record 需要在 completion 前记录，否则 completion 结束时的检测会获取不到 API Usage
                                                    [[MTHNetworkObserver sharedObserver] recordSessionAPIUsageWithRequestID:requestID session:(NSURLSession *)slf task:task];

                                                    completion(fileURLOrData, response, error);
                                                }];
                    task = ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzledSelector, argument, completionWrapper);
                    [self setRequestID:requestID forConnectionOrTask:task];
                } else {
                    task = ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzledSelector, argument, completion);
                }
                return task;
            };

            [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:asyncDataOrDownloadSwizzleBlock swizzledSelector:swizzledSelector];
        }
    });
}

+ (void)injectIntoNSURLSessionAsyncUploadTaskMethods {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURLSession class];

        // The method signatures here are close enough that we can use the same logic to inject into both of them.
        // Note that they have 3 arguments, so we can't easily combine with the data and download method above.
        const SEL selectors[] = {
            @selector(uploadTaskWithRequest:fromData:completionHandler:),
            @selector(uploadTaskWithRequest:fromFile:completionHandler:)
        };

        const int numSelectors = sizeof(selectors) / sizeof(SEL);

        for (int selectorIndex = 0; selectorIndex < numSelectors; selectorIndex++) {
            SEL selector = selectors[selectorIndex];
            SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

            if ([MTHawkeyeHooking instanceRespondsButDoesNotImplementSelector:selector onClass:class]) {
                // iOS 7 does not implement these methods on NSURLSession. We actually want to
                // swizzle __NSCFURLSession, which we can get from the class of the shared session
                class = [[NSURLSession sharedSession] class];
            }

            NSURLSessionUploadTask * (^asyncUploadTaskSwizzleBlock)(Class, NSURLRequest *, id, NSURLSessionAsyncCompletion) = ^NSURLSessionUploadTask *(Class slf, NSURLRequest *request, id argument, NSURLSessionAsyncCompletion completion) {
                NSURLSessionUploadTask *task = nil;
                if ([MTHNetworkObserver isEnabled]) {
                    NSString *requestID = [self nextRequestID];
                    NSString *mechanism = [self mechansimFromClassMethod:selector onClass:class];
                    NSURLSessionAsyncCompletion completionWrapper = [self asyncCompletionWrapperForRequestID:requestID mechanism:mechanism completion:completion];
                    task = ((id(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzledSelector, request, argument, completionWrapper);
                    [self setRequestID:requestID forConnectionOrTask:task];
                } else {
                    task = ((id(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzledSelector, request, argument, completion);
                }
                return task;
            };

            [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:asyncUploadTaskSwizzleBlock swizzledSelector:swizzledSelector];
        }
    });
}


// MARK: - Initialization
- (instancetype)init {
    if ((self = [super init])) {
        self.requestStatesForRequestIDs = [[NSMutableDictionary alloc] init];
        self.queue = dispatch_queue_create("com.meitu.hawkeye.network.observer", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// MARK: - private methods

- (void)performBlock:(dispatch_block_t)block {
    if ([[self class] isEnabled]) {
        dispatch_async(_queue, block);
    }
}

- (MTHawkeyeNetworkInternalRequestState *)requestStateForRequestID:(NSString *)requestID {
    MTHawkeyeNetworkInternalRequestState *requestState = self.requestStatesForRequestIDs[requestID];
    if (!requestState) {
        requestState = [[MTHawkeyeNetworkInternalRequestState alloc] init];
        [self.requestStatesForRequestIDs setObject:requestState forKey:requestID];
    }
    return requestState;
}

- (void)removeRequestStateForRequestID:(NSString *)requestID {
    [self.requestStatesForRequestIDs removeObjectForKey:requestID];
}

static char const *const kMTHNetworkRequestIDKey = "kMTHawkeyeNetworkRequestIDKey";

+ (NSString *)requestIDForConnectionOrTask:(id)connectionOrTask {
    NSString *requestID = objc_getAssociatedObject(connectionOrTask, kMTHNetworkRequestIDKey);
    if (!requestID) {
        requestID = [self nextRequestID];
        [self setRequestID:requestID forConnectionOrTask:connectionOrTask];
    }
    return requestID;
}

+ (void)setRequestID:(NSString *)requestID forConnectionOrTask:(id)connectionOrTask {
    objc_setAssociatedObject(connectionOrTask, kMTHNetworkRequestIDKey, requestID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSString *)mechansimFromClassMethod:(SEL)selector onClass:(Class)aClass {
    return [NSString stringWithFormat:@"+[%@ %@]", NSStringFromClass(aClass), NSStringFromSelector(selector)];
}

+ (NSURLSessionAsyncCompletion)asyncCompletionWrapperForRequestID:(NSString *)requestID mechanism:(NSString *)mechanism completion:(NSURLSessionAsyncCompletion)completion {
    NSURLSessionAsyncCompletion completionWrapper = ^(id fileURLOrData, NSURLResponse *response, NSError *error) {
        [[MTHNetworkRecorder defaultRecorder] recordMechanism:mechanism forRequestID:requestID];
        [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:response];
        NSData *data = nil;
        if ([fileURLOrData isKindOfClass:[NSURL class]]) {
            data = [NSData dataWithContentsOfURL:fileURLOrData];
        } else if ([fileURLOrData isKindOfClass:[NSData class]]) {
            data = fileURLOrData;
        }
        [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:[data length]];

        // Call through to the original completion handler
        if (completion) {
            completion(fileURLOrData, response, error);
        }

        if (error) {
            [[MTHNetworkRecorder defaultRecorder] recordLoadingFailedWithRequestID:requestID error:error];
        } else {
            [[MTHNetworkRecorder defaultRecorder] recordLoadingFinishedWithRequestID:requestID responseBody:data];
        }
    };
    return completionWrapper;
}

@end


// MARK: -

@implementation MTHNetworkObserver (NSURLConnectionMHTHelpers)

- (void)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        requestState.request = request;

        [[MTHNetworkRecorder defaultRecorder] recordRequestWillBeSentWithRequestID:requestID request:request redirectResponse:response];
        NSString *mechanism = [NSString stringWithFormat:@"NSURLConnection (delegate: %@)", [impl class]];
        [[MTHNetworkRecorder defaultRecorder] recordMechanism:mechanism forRequestID:requestID];
    }];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        NSMutableData *dataAccumulator = nil;
        if (response.expectedContentLength < 0) {
            dataAccumulator = [[NSMutableData alloc] init];
        } else {
            dataAccumulator = [[NSMutableData alloc] initWithCapacity:(NSUInteger)response.expectedContentLength];
        }
        requestState.dataAccumulator = dataAccumulator;

        [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:response];
    }];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data impl:(id)impl {
    // Just to be safe since we're doing this async
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [requestState.dataAccumulator appendData:data];

        [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:data.length];
    }];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [[MTHNetworkRecorder defaultRecorder] recordLoadingFinishedWithRequestID:requestID responseBody:requestState.dataAccumulator];
        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        // Cancellations can occur prior to the willSendRequest:... NSURLConnection delegate call.
        // These are pretty common and clutter up the logs. Only record the failure if the recorder already knows about the request through willSendRequest:...
        if (requestState.request) {
            [[MTHNetworkRecorder defaultRecorder] recordLoadingFailedWithRequestID:requestID error:error];
        }

        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)connectionWillCancel:(NSURLConnection *)connection {
    [self performBlock:^{
        // Mimic the behavior of NSURLSession which is to create an error on cancellation.
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"cancelled"};
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
        [self connection:connection didFailWithError:error impl:nil];
    }];
}

@end


@implementation MTHNetworkObserver (NSURLSessionTaskMTHHelpers)

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        [[MTHNetworkRecorder defaultRecorder] recordRequestWillBeSentWithRequestID:requestID request:request redirectResponse:response];
    }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        NSMutableData *dataAccumulator = nil;
        if (response.expectedContentLength < 0) {
            dataAccumulator = [[NSMutableData alloc] init];
        } else {
            dataAccumulator = [[NSMutableData alloc] initWithCapacity:(NSUInteger)response.expectedContentLength];
        }
        requestState.dataAccumulator = dataAccumulator;

        NSString *requestMechanism = [NSString stringWithFormat:@"NSURLSessionDataTask (delegate: %@)", [impl class]];
        [[MTHNetworkRecorder defaultRecorder] recordMechanism:requestMechanism forRequestID:requestID];

        [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:response];
    }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data impl:(id)impl {
    // Just to be safe since we're doing this async
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        [requestState.dataAccumulator appendData:data];

        [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:data.length];
    }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask impl:(id)impl {
    [self performBlock:^{
        // By setting the request ID of the download task to match the data task,
        // it can pick up where the data task left off.
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        [[self class] setRequestID:requestID forConnectionOrTask:downloadTask];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        [self recordSessionAPIUsageWithRequestID:requestID session:session task:task];

        if (error) {
            [[MTHNetworkRecorder defaultRecorder] recordLoadingFailedWithRequestID:requestID error:error];
        } else {
            [[MTHNetworkRecorder defaultRecorder] recordLoadingFinishedWithRequestID:requestID responseBody:requestState.dataAccumulator];
        }

        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        [[MTHNetworkRecorder defaultRecorder] recordMetricsWithRequestID:requestID metrics:metrics];
    }];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite impl:(id)impl {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:downloadTask];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        if (!requestState.dataAccumulator) {
#if MTHawkeyeNetworkDebugEnabled
            MTHLogDebug(@"start write dataAccumulator");
#endif
            NSUInteger unsignedBytesExpectedToWrite = totalBytesExpectedToWrite > 0 ? (NSUInteger)totalBytesExpectedToWrite : 0;
            requestState.dataAccumulator = [[NSMutableData alloc] initWithCapacity:unsignedBytesExpectedToWrite];
            [[MTHNetworkRecorder defaultRecorder] recordResponseReceivedWithRequestID:requestID response:downloadTask.response];

            NSString *requestMechanism = [NSString stringWithFormat:@"NSURLSessionDownloadTask (delegate: %@)", [impl class]];
            [[MTHNetworkRecorder defaultRecorder] recordMechanism:requestMechanism forRequestID:requestID];
        }

        [[MTHNetworkRecorder defaultRecorder] recordDataReceivedWithRequestID:requestID dataLength:bytesWritten];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location data:(NSData *)data impl:(id)impl {
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:downloadTask];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [requestState.dataAccumulator appendData:data];
    }];
}

- (void)URLSessionTaskWillResume:(NSURLSessionTask *)task {
    // Since resume can be called multiple times on the same task, only treat the first resume as
    // the equivalent to connection:willSendRequest:...
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        MTHawkeyeNetworkInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        if (!requestState.request) {
            requestState.request = task.currentRequest;
            [[MTHNetworkRecorder defaultRecorder] recordRequestWillBeSentWithRequestID:requestID request:task.currentRequest redirectResponse:nil];
        }
    }];
}

// MARK: -
- (void)recordSessionAPIUsageWithRequestID:(NSString *)requestID session:(NSURLSession *)session task:(NSURLSessionTask *)task {
    // 记录 SessionTask 相关 API 使用情况，用于后续的网络侦测建议
    MTHNetworkTaskAPIUsage *taskAPIUsage = [[MTHNetworkTaskAPIUsage alloc] init];
    taskAPIUsage.taskPriority = task.priority;
    taskAPIUsage.taskSessionIdentify = [NSString stringWithFormat:@"%p", (void *)session];

    MTHNetworkTaskSessionConfigAPIUsage *sessionCfgAPIUsage = [[MTHNetworkTaskSessionConfigAPIUsage alloc] init];
    sessionCfgAPIUsage.sessionConfigShouldUsePipeliningEnabled = session.configuration.HTTPShouldUsePipelining;
    sessionCfgAPIUsage.sessionConfigTimeoutIntervalForRequest = session.configuration.timeoutIntervalForRequest;
    sessionCfgAPIUsage.sessionConfigTimeoutIntervalForResource = session.configuration.timeoutIntervalForResource;
    sessionCfgAPIUsage.sessionConfigHTTPMaximumConnectionsPerHost = session.configuration.HTTPMaximumConnectionsPerHost;

    [[MTHNetworkRecorder defaultRecorder] recordRequestTaskAPIUsageWithRequestID:requestID
                                                                    taskAPIUsage:taskAPIUsage
                                                       taskSessionConfigAPIUsage:sessionCfgAPIUsage];
}

@end
