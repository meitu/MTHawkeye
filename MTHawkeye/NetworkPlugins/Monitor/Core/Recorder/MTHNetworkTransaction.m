//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/07/2017
// Created by: EuanC
//


#import "MTHNetworkTransaction.h"
#import "NSData+MTHawkeyeNetwork.h"

#import <dlfcn.h>

@implementation MTHNetworkTaskAPIUsage
@end

@implementation MTHNetworkTaskSessionConfigAPIUsage
@end

typedef CFHTTPMessageRef (*MTHURLResponseGetHTTPResponse)(CFURLRef response);

@interface MTHNetworkTransaction ()

@property (nonatomic, copy, readwrite) NSData *cachedRequestBody;
@property (nonatomic, assign, readwrite) BOOL useURLSessionTaskMetrics;

@end

@implementation MTHNetworkTransaction


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (void)setTaskMetrics:(MTHURLSessionTaskMetrics *)taskMetrics {
    self.useURLSessionTaskMetrics = (taskMetrics != nil);
    _taskMetrics = taskMetrics;
}

- (NSDate *)startTime {
    if (self.useURLSessionTaskMetrics) {
        return self.taskMetrics.taskInterval.startDate;
    } else {
        return _startTime;
    }
}

- (NSTimeInterval)latency {
    if (self.useURLSessionTaskMetrics) {
        MTHURLSessionTaskTransactionMetrics *metrics = self.taskMetrics.transactionMetrics.lastObject;
        NSTimeInterval latency = [metrics.responseStartDate timeIntervalSinceDate:self.taskMetrics.taskInterval.startDate];
        return latency;
    } else {
        return _latency;
    }
}

- (NSTimeInterval)duration {
    if (self.useURLSessionTaskMetrics) {
        return self.taskMetrics.taskInterval.duration;
    } else {
        return _duration;
    }
}

- (NSString *)description {
    NSString *description = [super description];

    description = [description stringByAppendingFormat:@" id = %@;", self.requestID];
    description = [description stringByAppendingFormat:@" url = %@;", self.request.URL];
    description = [description stringByAppendingFormat:@" duration = %f;", self.duration];
    description = [description stringByAppendingFormat:@" receivedDataLength = %lld", self.receivedDataLength];

    return description;
}

- (MTHNetworkHTTPContentType)responseContentType {

    NSString *mimeType = self.response.MIMEType;

    if (!mimeType) {
        return MTHNetworkHTTPContentTypeNULL;
    }

    if ([mimeType hasPrefix:@"application/json"]) {
        _responseContentType = MTHNetworkHTTPContentTypeJSON;
    } else if ([mimeType hasPrefix:@"application/xml"]) {
        _responseContentType = MTHNetworkHTTPContentTypeXML;
    } else if ([mimeType hasPrefix:@"text/"]) {
        _responseContentType = MTHNetworkHTTPContentTypeText;
    } else if ([mimeType hasPrefix:@"text/html"]) {
        _responseContentType = MTHNetworkHTTPContentTypeHTML;
    } else {
        _responseContentType = MTHNetworkHTTPContentTypeOther;
    }

    return _responseContentType;
}

- (NSData *)cachedRequestBody {
    if (!_cachedRequestBody) {
        if (self.request.HTTPBody != nil) {
            _cachedRequestBody = self.request.HTTPBody;
        } else if ([self.request.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)]) {
            NSInputStream *bodyStream = [self.request.HTTPBodyStream copy];
            const NSUInteger bufferSize = 1024;
            uint8_t buffer[bufferSize];
            NSMutableData *data = [NSMutableData data];
            [bodyStream open];
            NSInteger readBytes = 0;
            do {
                readBytes = [bodyStream read:buffer maxLength:bufferSize];
                [data appendBytes:buffer length:readBytes];
            } while (readBytes > 0);
            [bodyStream close];
            _cachedRequestBody = data;
        }
    }
    return _cachedRequestBody;
}

- (NSInteger)requestLength {
    if (!_requestLength) {
        NSString *lineStr = [NSString stringWithFormat:@"%@ %@ %@\r\n", self.request.HTTPMethod, self.request.URL.path, @"HTTP/1.1"];
        NSData *lineData = [lineStr dataUsingEncoding:NSUTF8StringEncoding];

        NSMutableString *headerStr = [[NSMutableString alloc] init];
        [self.request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
            [headerStr appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
        }];
        NSData *headersData = [headerStr dataUsingEncoding:NSUTF8StringEncoding];

        NSData *bodyData = self.request.HTTPBody;

        _requestLength = lineData.length + headersData.length + bodyData.length;
    }
    return _requestLength;
}

- (NSInteger)responseLength {
    if (!_responseLength) {
        NSString *funName = @"CFURLResponseGetHTTPResponse";
        MTHURLResponseGetHTTPResponse originURLResponseGetHTTPResponse = dlsym(RTLD_DEFAULT, [funName UTF8String]);

        NSString *statusLine = @"";
        SEL theSelector = NSSelectorFromString(@"_CFURLResponse");
        if ([self.response respondsToSelector:theSelector] && NULL != originURLResponseGetHTTPResponse) {
            // 获取NSURLResponse的_CFURLResponse
            CFTypeRef cfResponse = CFBridgingRetain(((id(*)(id, SEL))[self.response methodForSelector:theSelector])(self.response, theSelector));
            if (NULL != cfResponse) {
                // 将CFURLResponseRef转化为CFHTTPMessageRef
                CFHTTPMessageRef messageRef = originURLResponseGetHTTPResponse(cfResponse);
                if (NULL != messageRef) {
                    statusLine = (__bridge_transfer NSString *)CFHTTPMessageCopyResponseStatusLine(messageRef);
                    CFRelease(cfResponse);
                } else {
                    CFRelease(cfResponse);
                }
            }
        }

        // status-line 计算的补充
        NSMutableString *lineStr = @"".mutableCopy;
        [lineStr appendString:statusLine];
        NSArray *statusLineArr = [statusLine componentsSeparatedByString:@" "];
        if (statusLineArr.count == 2 && ![statusLine hasSuffix:@" "]) {
            [lineStr appendString:@" "];
        }
        if (![lineStr hasSuffix:@"\r\n"]) {
            [lineStr appendString:@"\r\n"];
        }
        NSData *lineData = [lineStr dataUsingEncoding:NSUTF8StringEncoding];

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self.response;
        NSString *headerStr = @"";
        for (NSString *key in httpResponse.allHeaderFields.allKeys) {
            headerStr = [headerStr stringByAppendingString:key];
            headerStr = [headerStr stringByAppendingString:@": "];
            if ([httpResponse.allHeaderFields objectForKey:key]) {
                headerStr = [headerStr stringByAppendingString:httpResponse.allHeaderFields[key]];
            }
            headerStr = [headerStr stringByAppendingString:@"\r\n"];
        }
        headerStr = [headerStr stringByAppendingString:@"\r\n"];
        NSData *headerData = [headerStr dataUsingEncoding:NSUTF8StringEncoding];

        NSData *responseData;
        if ([[httpResponse.allHeaderFields objectForKey:@"Content-Encoding"] isEqualToString:@"gzip"]) {
            responseData = [self.responseBody MTHNetwork_gzippedData];
        } else {
            responseData = self.responseBody;
        }
        _responseLength = lineData.length + headerData.length + responseData.length;
    }
    return _responseLength;
}

+ (NSString *)readableStringFromTransactionState:(MTHNetworkTransactionState)state {
    NSString *readableString = nil;
    switch (state) {
        case MTHNetworkTransactionStateUnstarted:
            readableString = @"Unstarted";
            break;

        case MTHNetworkTransactionStateAwaitingResponse:
            readableString = @"Awaiting Response";
            break;

        case MTHNetworkTransactionStateReceivingData:
            readableString = @"Receiving Data";
            break;

        case MTHNetworkTransactionStateFinished:
            readableString = @"Finished";
            break;

        case MTHNetworkTransactionStateFailed:
            readableString = @"Failed";
            break;
    }
    return readableString;
}

#pragma clang diagnostic pop

+ (instancetype)transactionFromPropertyDictionary:(NSDictionary *)dictionary {
    if (!dictionary || !dictionary.count) {
        return nil;
    }

    NSDictionary *requestDictionary = dictionary[@"request"];
    if (!requestDictionary) {
        return nil;
    }

    NSDictionary *responseDictionary = dictionary[@"response"];
    if (!responseDictionary) {
        return nil;
    }

    MTHNetworkTransaction *transation = [[MTHNetworkTransaction alloc] init];
    transation.requestID = dictionary[@"id"];
    transation.requestIndex = [dictionary[@"index"] integerValue];
    transation.requestMechanism = dictionary[@"request_mechanism"];
    NSString *localizedErrorDescription = dictionary[@"error"];
    if (localizedErrorDescription.length) {
        transation.error = [[NSError alloc] initWithDomain:NSNetServicesErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : localizedErrorDescription}];
    }
    transation.startTime = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"start_time"] doubleValue]];
    transation.latency = [dictionary[@"latency"] doubleValue];
    transation.duration = [dictionary[@"duration"] doubleValue];
    transation.isUsingURLSession = [dictionary[@"is_session"] boolValue];
    transation.transactionState = [dictionary[@"state"] integerValue];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSURL *url = [NSURL URLWithString:requestDictionary[@"url"] ?: @""];
    request.URL = url;
    request.timeoutInterval = [requestDictionary[@"timeout"] doubleValue];
    request.HTTPMethod = requestDictionary[@"http_method"] ?: @"GET";
    request.allHTTPHeaderFields = [requestDictionary[@"headers"] copy];
    request.HTTPBody = [requestDictionary[@"body"] dataUsingEncoding:NSUTF8StringEncoding];
    transation.request = [request copy];
    transation.requestLength = [dictionary[@"request_length"] integerValue];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                              statusCode:[responseDictionary[@"status_code"] integerValue]
                                                             HTTPVersion:nil
                                                            headerFields:responseDictionary[@"headers"]];
    transation.response = response;
    transation.responseLength = [dictionary[@"response_length"] integerValue];
    transation.receivedDataLength = [responseDictionary[@"recv_data_len"] integerValue];
    transation.responseDataMD5 = responseDictionary[@"responseDataMD5"];
    transation.responseBody = [responseDictionary[@"body"] dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *taskMetricsDictionary;
    if ((taskMetricsDictionary = dictionary[@"task_metrics"])) {
        if (@available(iOS 10.0, *)) {
            MTHURLSessionTaskMetrics *taskMetrics = [[MTHURLSessionTaskMetrics alloc] init];
            taskMetrics.redirectCount = ((NSNumber *)taskMetricsDictionary[@"redirect_count"]).unsignedIntegerValue;

            NSDictionary *taskIntervalDictionary = taskMetricsDictionary[@"task_interval"];
            NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[taskIntervalDictionary[@"start"] doubleValue]];
            NSDateInterval *dateInterval = [[NSDateInterval alloc] initWithStartDate:startDate
                                                                            duration:[taskIntervalDictionary[@"duration"] doubleValue]];
            taskMetrics.taskInterval = dateInterval;

            NSArray<NSDictionary *> *transactionMetricsDictionaryArray = taskMetricsDictionary[@"transaction_metrics"];
            NSMutableArray<MTHURLSessionTaskTransactionMetrics *> *transactionMetricsArray = [NSMutableArray arrayWithCapacity:transactionMetricsDictionaryArray.count];
            for (NSDictionary *transMetricsDictionary in transactionMetricsDictionaryArray) {
                MTHURLSessionTaskTransactionMetrics *transMetrics = [[MTHURLSessionTaskTransactionMetrics alloc] init];
                transMetrics.request = request;
                transMetrics.resourceFetchType = ((NSNumber *)transMetricsDictionary[@"type"]).integerValue;
                transMetrics.fetchStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"fetch_start"] doubleValue]];
                transMetrics.domainLookupStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"dns_start"] doubleValue]];
                transMetrics.domainLookupEndDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"dns_end"] doubleValue]];
                transMetrics.connectStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"conn_start"] doubleValue]];
                transMetrics.connectEndDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"conn_end"] doubleValue]];
                transMetrics.secureConnectionStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"sec_conn_start"] doubleValue]];
                transMetrics.secureConnectionEndDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"sec_conn_end"] doubleValue]];
                transMetrics.requestStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"req_start"] doubleValue]];
                transMetrics.requestEndDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"req_end"] doubleValue]];
                transMetrics.responseStartDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"res_start"] doubleValue]];
                transMetrics.responseEndDate = [NSDate dateWithTimeIntervalSince1970:[transMetricsDictionary[@"res_end"] doubleValue]];
                transMetrics.networkProtocolName = transMetricsDictionary[@"protocol"];
                [transactionMetricsArray addObject:transMetrics];
            }

            if (transactionMetricsArray.count) {
                taskMetrics.transactionMetrics = transactionMetricsArray;
            }

            transation.taskMetrics = taskMetrics;
        } else {
            // Fallback on earlier versions
        }
    }

    NSDictionary *taskAPIUsageDictionary;
    if ((taskAPIUsageDictionary = dictionary[@"task_api_usage"])) {
        MTHNetworkTaskAPIUsage *taskAPIUsage = [[MTHNetworkTaskAPIUsage alloc] init];
        taskAPIUsage.taskSessionIdentify = taskAPIUsageDictionary[@"session_id"];
        taskAPIUsage.taskPriority = (CGFloat)[taskAPIUsageDictionary[@"task_priority"] doubleValue];
        transation.sessionTaskAPIUsage = taskAPIUsage;
    }

    NSDictionary *sessionConfigAPIUsageDictionary;
    if ((sessionConfigAPIUsageDictionary = dictionary[@"config_api_usage"])) {
        MTHNetworkTaskSessionConfigAPIUsage *sessionConfigAPIUsage = [[MTHNetworkTaskSessionConfigAPIUsage alloc] init];
        sessionConfigAPIUsage.sessionConfigShouldUsePipeliningEnabled = [sessionConfigAPIUsageDictionary[@"pipelining"] boolValue];
        sessionConfigAPIUsage.sessionConfigTimeoutIntervalForRequest = [sessionConfigAPIUsageDictionary[@"timeout_request"] doubleValue];
        sessionConfigAPIUsage.sessionConfigTimeoutIntervalForResource = [sessionConfigAPIUsageDictionary[@"timeout_response"] doubleValue];
        sessionConfigAPIUsage.sessionConfigHTTPMaximumConnectionsPerHost = [sessionConfigAPIUsageDictionary[@"max_conn_per_host"] integerValue];
        transation.sessionConfigAPIUsage = sessionConfigAPIUsage;
    }

    return transation;
}

- (NSDictionary *)dictionaryFromAllProperty {
    NSMutableDictionary *dict = @{}.mutableCopy;
    dict[@"id"] = self.requestID ?: @"";
    dict[@"index"] = @(self.requestIndex);
    dict[@"request_mechanism"] = self.requestMechanism ?: @"";
    dict[@"error"] = self.error ? [self.error localizedDescription] : @"";
    dict[@"start_time"] = @([self.startTime timeIntervalSince1970]);
    dict[@"latency"] = @(self.latency);
    dict[@"duration"] = @(self.duration);
    dict[@"is_session"] = @(self.isUsingURLSession);
    dict[@"state"] = @(self.transactionState);

    NSMutableDictionary *request = @{}.mutableCopy;
    request[@"url"] = self.request.URL.absoluteString ?: @"";
    request[@"timeout"] = @(self.request.timeoutInterval);
    request[@"http_method"] = self.request.HTTPMethod ?: @"";

    NSMutableDictionary *requestHeader = @{}.mutableCopy;
    [self.request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
        requestHeader[key] = obj ?: @"";
    }];
    request[@"headers"] = requestHeader.copy;
    request[@"body"] = [[NSString alloc] initWithData:self.cachedRequestBody encoding:NSUTF8StringEncoding];
    dict[@"request"] = request.copy;
    dict[@"request_length"] = @(self.requestLength);

    NSMutableDictionary *response = @{}.mutableCopy;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self.response;
    response[@"status_code"] = @(httpResponse.statusCode);
    response[@"recv_data_len"] = @(self.receivedDataLength);
    response[@"responseDataMD5"] = self.responseDataMD5 ?: @"";

    NSMutableDictionary *responseHeader = @{}.mutableCopy;
    [httpResponse.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
        responseHeader[key] = obj ?: @"";
    }];
    response[@"headers"] = responseHeader.copy;

    response[@"body"] = [[NSString alloc] initWithData:self.responseBody encoding:NSUTF8StringEncoding];
    dict[@"response"] = response.copy;
    dict[@"response_length"] = @(self.responseLength);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if (self.taskMetrics) {
        NSMutableDictionary *taskMetrics = @{}.mutableCopy;
        taskMetrics[@"redirect_count"] = @(self.taskMetrics.redirectCount);
        NSDictionary *taskInterval = @{
            @"start" : @([self.taskMetrics.taskInterval.startDate timeIntervalSince1970]),
            @"end" : @([self.taskMetrics.taskInterval.endDate timeIntervalSince1970]),
            @"duration" : @(self.taskMetrics.taskInterval.duration),
        };
        taskMetrics[@"task_interval"] = taskInterval.copy;

        NSMutableArray *transactionMetrics = @[].mutableCopy;
        for (MTHURLSessionTaskTransactionMetrics *metrics in self.taskMetrics.transactionMetrics) {
            NSMutableDictionary *metricsDict = @{}.mutableCopy;
            metricsDict[@"request_url"] = metrics.request.URL.absoluteString ?: @"";
            metricsDict[@"type"] = @(metrics.resourceFetchType);
            metricsDict[@"fetch_start"] = @([metrics.fetchStartDate timeIntervalSince1970]);
            metricsDict[@"dns_start"] = @([metrics.domainLookupStartDate timeIntervalSince1970]);
            metricsDict[@"dns_end"] = @([metrics.domainLookupEndDate timeIntervalSince1970]);
            metricsDict[@"conn_start"] = @([metrics.connectStartDate timeIntervalSince1970]);
            metricsDict[@"conn_end"] = @([metrics.connectEndDate timeIntervalSince1970]);
            metricsDict[@"sec_conn_start"] = @([metrics.secureConnectionStartDate timeIntervalSince1970]);
            metricsDict[@"sec_conn_end"] = @([metrics.secureConnectionEndDate timeIntervalSince1970]);
            metricsDict[@"req_start"] = @([metrics.requestStartDate timeIntervalSince1970]);
            metricsDict[@"req_end"] = @([metrics.requestEndDate timeIntervalSince1970]);
            metricsDict[@"res_start"] = @([metrics.responseStartDate timeIntervalSince1970]);
            metricsDict[@"res_end"] = @([metrics.responseEndDate timeIntervalSince1970]);
            metricsDict[@"protocol"] = metrics.networkProtocolName ?: @"h1";

            [transactionMetrics addObject:metricsDict.copy];
        }
        taskMetrics[@"transaction_metrics"] = transactionMetrics.copy;

        dict[@"task_metrics"] = taskMetrics.copy;
    }
#pragma clang diagnostic pop

    if (self.sessionTaskAPIUsage) {
        dict[@"task_api_usage"] = @{
            @"session_id" : self.sessionTaskAPIUsage.taskSessionIdentify ?: @"",
            @"task_priority" : @(self.sessionTaskAPIUsage.taskPriority),
        };
    }
    if (self.sessionConfigAPIUsage) {
        dict[@"config_api_usage"] = @{
            @"pipelining" : @(self.sessionConfigAPIUsage.sessionConfigShouldUsePipeliningEnabled),
            @"timeout_request" : @(self.sessionConfigAPIUsage.sessionConfigTimeoutIntervalForRequest),
            @"timeout_response" : @(self.sessionConfigAPIUsage.sessionConfigTimeoutIntervalForResource),
            @"max_conn_per_host" : @(self.sessionConfigAPIUsage.sessionConfigHTTPMaximumConnectionsPerHost),
        };
    }

    return dict.copy;
}

@end
