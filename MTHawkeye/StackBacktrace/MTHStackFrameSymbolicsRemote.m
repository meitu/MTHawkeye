//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/22
// Created by: EuanC
//


#import "MTHStackFrameSymbolicsRemote.h"

static NSString *symbolicsServerURL = nil;
static NSTimeInterval symbolicsTaskTimeoutInSeconds = 20;

@implementation MTHStackFrameSymbolicsRemote

+ (NSString *)symbolicsServerURL {
    return symbolicsServerURL;
}

+ (void)configureSymbolicsServerURL:(NSString *)serverURL {
    symbolicsServerURL = serverURL;
}

+ (void)configureSymbolicsTaskTimeout:(NSTimeInterval)timeoutInSeconds {
    symbolicsTaskTimeoutInSeconds = timeoutInSeconds;
}

+ (NSError *)errorWithMessage:(NSString *)msg code:(NSInteger)code {
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey : msg ?: @""
    };
    return [NSError errorWithDomain:@"com.meitu.hawkeye.stack_backtrace.symbolics" code:code userInfo:userInfo];
}

+ (void)symbolizeStackFrames:(NSArray<NSString *> *)framePointers
         withDyldImagesInfos:(NSDictionary *)dyldImagesInfo
           completionHandler:(void (^)(NSArray<NSDictionary<NSString *, NSString *> *> *symbolizedFrames, NSError *error))completionHandler {
    if (symbolicsServerURL.length == 0) {
        completionHandler(nil, [self errorWithMessage:@"You should configure symbolics server firstly." code:-1]);
        return;
    }

    if (framePointers.count == 0) {
        completionHandler(nil, [self errorWithMessage:@"empty frames" code:-1]);
        return;
    }
    if (![framePointers[0] isKindOfClass:[NSString class]]) {
        completionHandler(nil, [self errorWithMessage:@"framePointers element should form in NSString *" code:-2]);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:symbolicsServerURL]];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval:symbolicsTaskTimeoutInSeconds];

    NSData *jsonData = nil;
    {
        NSMutableDictionary *jsonDict = @{}.mutableCopy;
        jsonDict[@"stack_frames"] = framePointers;
        jsonDict[@"dyld_images_info"] = dyldImagesInfo;

        NSError *error = nil;
        jsonData = [NSJSONSerialization dataWithJSONObject:[jsonDict copy] options:NSJSONWritingPrettyPrinted error:&error];
        if (!jsonData) {
            completionHandler(nil, error);
            return;
        }
    }

    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%@", @([jsonData length])] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:jsonData];

    void (^responseHandler)(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) = ^void(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            NSError *error = nil;
            NSDictionary *resultJsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                completionHandler(nil, error);
            } else {
                if (![resultJsonDict isKindOfClass:[NSDictionary class]]) {
                    NSString *msg = [NSString stringWithFormat:@"response data format error: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                    completionHandler(nil, [self errorWithMessage:msg code:-3]);
                    return;
                }

                NSArray *frameDicts = resultJsonDict[@"stack_frames"];
                if (![frameDicts isKindOfClass:[NSArray class]] || frameDicts.count == 0) {
                    NSString *msg = [NSString stringWithFormat:@"response frames empty/unexpected: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                    completionHandler(nil, [self errorWithMessage:msg code:-4]);
                    return;
                }
                NSString *errorMsg = resultJsonDict[@"error"][@"msg"];
                if (errorMsg.length > 0) {
                    error = [self errorWithMessage:errorMsg code:-5];
                }

                completionHandler(frameDicts, error);
            }
        }
    };

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:responseHandler]
        resume];
}

@end
