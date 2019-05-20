//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/08/2017
// Created by: EuanC
//


#import "MTHURLSessionDelegateProxy.h"
#import "MTHNetworkObserver.h"

@interface MTHNetworkObserver (_NSURLSessionTaskMTHHelpers)

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data impl:(id)impl;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics impl:(id)impl NS_AVAILABLE_IOS(10_0);
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite impl:(id)impl;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location data:(NSData *)data impl:(id)impl;

@end

// MARK: -

@interface MTHURLSessionDelegateProxy ()

@property (nonatomic, strong) id originalDelegate;
@property (nonatomic, weak) MTHNetworkObserver *observer;

@end

@implementation MTHURLSessionDelegateProxy

- (instancetype)initWithOriginalDelegate:(nullable id)delegate observer:(MTHNetworkObserver *)observer {
    if ((self = [super init])) {
        self.originalDelegate = delegate;
        self.observer = observer;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([self.originalDelegate respondsToSelector:aSelector]) {
        return YES;
    }

    return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.originalDelegate;
}

// MARK: -
- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *_Nullable))completionHandler {

    [self.observer URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [self.originalDelegate URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(request);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    [self.observer URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [self.originalDelegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.observer URLSession:session dataTask:dataTask didReceiveData:data impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [self.originalDelegate URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    [self.observer URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:dataTask:didBecomeDownloadTask:)]) {
        [self.originalDelegate URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    [self.observer URLSession:session task:task didCompleteWithError:error impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [self.originalDelegate URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics NS_AVAILABLE_IOS(10_0) {
    [self.observer URLSession:session task:task didFinishCollectingMetrics:metrics impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [self.originalDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    [self.observer URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
        [self.originalDelegate URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSData *data = [NSData dataWithContentsOfFile:location.relativePath];
    [self.observer URLSession:session task:downloadTask didFinishDownloadingToURL:location data:data impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:downloadTask:didFinishDownloadingToURL:)]) {
        [self.originalDelegate URLSession:session downloadTask:downloadTask didFinishDownloadingToURL:location];
    }
}

// MARK: default imp
- (void)URLSession:(NSURLSession *)session
                 task:(NSURLSessionTask *)task
    needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:needNewBodyStream:)]) {
        [self.originalDelegate URLSession:session task:task needNewBodyStream:completionHandler];
    } else {
        NSInputStream *inputStream = nil;
        if (completionHandler) {
            completionHandler(inputStream);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
                   task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [self.originalDelegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        __block NSURLCredential *credential = nil;
        if (completionHandler) {
            completionHandler(disposition, credential);
        }
    }
}

@end
