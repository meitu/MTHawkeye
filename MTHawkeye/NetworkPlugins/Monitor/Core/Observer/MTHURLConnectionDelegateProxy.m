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


#import "MTHURLConnectionDelegateProxy.h"
#import "MTHNetworkObserver.h"


@interface MTHNetworkObserver (_NSURLConnectionHelpers)

- (void)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data impl:(id)impl;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection impl:(id)impl;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error impl:(id)impl;

@end

// MARK: -

@interface MTHURLConnectionDelegateProxy ()

@property (nonatomic, strong) id originalDelegate;
@property (nonatomic, weak) MTHNetworkObserver *observer;

@end


@implementation MTHURLConnectionDelegateProxy

- (instancetype)initWithOriginalDelegate:(id)originalDelegate observer:(MTHNetworkObserver *)observer {
    self.originalDelegate = originalDelegate;
    self.observer = observer;
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([self.originalDelegate respondsToSelector:aSelector]) {
        return YES;
    }

    return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([self.originalDelegate respondsToSelector:aSelector]) {
        return self.originalDelegate;
    }

    return nil;
}

// MARK: -
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.observer connectionDidFinishLoading:connection impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(connectionDidFinishLoading:)]) {
        [self.originalDelegate connectionDidFinishLoading:connection];
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    [self.observer connection:connection willSendRequest:request redirectResponse:response impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)]) {
        id resultRequest = [self.originalDelegate connection:connection willSendRequest:request redirectResponse:response];
        return resultRequest;
    } else {
        return request;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.observer connection:connection didReceiveResponse:response impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
        [self.originalDelegate connection:connection didReceiveResponse:response];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.observer connection:connection didReceiveData:data impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [self.originalDelegate connection:connection didReceiveData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.observer connection:connection didFailWithError:error impl:self.originalDelegate];

    if ([self.originalDelegate respondsToSelector:@selector(connection:didFailWithError:)]) {
        [self.originalDelegate connection:connection didFailWithError:error];
    }
}

@end
