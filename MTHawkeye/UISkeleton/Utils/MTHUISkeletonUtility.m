//
// Copyright (c) 2014-2016, Flipboard
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 6/10/14
// Created by: Ryan Olson
//


#import "MTHUISkeletonUtility.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <zlib.h>

@implementation MTHUISkeletonUtility


+ (UIFont *)defaultFontOfSize:(CGFloat)size {
    return [UIFont fontWithName:@"HelveticaNeue" size:size];
}

+ (UIFont *)defaultTableViewCellLabelFont {
    return [self defaultFontOfSize:12.0];
}

+ (UIFont *)codeFontWithSize:(NSInteger)size {
    UIFont *font = [UIFont fontWithName:@"Menlo" size:size];
    if (!font) {
        font = [UIFont fontWithName:@"Courier" size:size];
    }
    return font;
}

+ (NSString *)stringByEscapingHTMLEntitiesInString:(NSString *)originalString {
    static NSDictionary *escapingDictionary = nil;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        escapingDictionary = @{@" " : @"&nbsp;",
            @">" : @"&gt;",
            @"<" : @"&lt;",
            @"&" : @"&amp;",
            @"'" : @"&apos;",
            @"\"" : @"&quot;",
            @"«" : @"&laquo;",
            @"»" : @"&raquo;"};
        regex = [NSRegularExpression regularExpressionWithPattern:@"(&|>|<|'|\"|«|»)" options:0 error:NULL];
    });

    NSMutableString *mutableString = [originalString mutableCopy];

    NSArray *matches = [regex matchesInString:mutableString options:0 range:NSMakeRange(0, [mutableString length])];
    for (NSTextCheckingResult *result in [matches reverseObjectEnumerator]) {
        NSString *foundString = [mutableString substringWithRange:result.range];
        NSString *replacementString = escapingDictionary[foundString];
        if (replacementString) {
            [mutableString replaceCharactersInRange:result.range withString:replacementString];
        }
    }

    return [mutableString copy];
}



+ (NSString *)stringFromRequestDuration:(NSTimeInterval)duration {
    NSString *string = @"0s";
    if (duration > 0.0) {
        if (duration < 1.0) {
            string = [NSString stringWithFormat:@"%dms", (int)(duration * 1000)];
        } else if (duration < 10.0) {
            string = [NSString stringWithFormat:@"%.2fs", duration];
        } else {
            string = [NSString stringWithFormat:@"%.1fs", duration];
        }
    }
    return string;
}

+ (NSString *)statusCodeStringFromURLResponse:(NSURLResponse *)response {
    NSString *httpResponseString = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *statusCodeDescription = nil;
        if (httpResponse.statusCode == 200) {
            // Prefer OK to the default "no error"
            statusCodeDescription = @"OK";
        } else {
            statusCodeDescription = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];
        }
        httpResponseString = [NSString stringWithFormat:@"%ld %@", (long)httpResponse.statusCode, statusCodeDescription];
    }
    return httpResponseString;
}

+ (BOOL)isErrorStatusCodeFromURLResponse:(NSURLResponse *)response {
    NSIndexSet *errorStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(400, 200)];

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        return [errorStatusCodes containsIndex:httpResponse.statusCode];
    }

    return NO;
}


+ (NSDictionary *)dictionaryFromQuery:(NSString *)query {
    NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];

    // [a=1, b=2, c=3]
    NSArray *queryComponents = [query componentsSeparatedByString:@"&"];
    for (NSString *keyValueString in queryComponents) {
        // [a, 1]
        NSArray *components = [keyValueString componentsSeparatedByString:@"="];
        if ([components count] == 2) {
            NSString *key = [[components firstObject] stringByRemovingPercentEncoding];
            id value = [[components lastObject] stringByRemovingPercentEncoding];

            // Handle multiple entries under the same key as an array
            id existingEntry = queryDictionary[key];
            if (existingEntry) {
                if ([existingEntry isKindOfClass:[NSArray class]]) {
                    value = [existingEntry arrayByAddingObject:value];
                } else {
                    value = @[ existingEntry, value ];
                }
            }

            [queryDictionary setObject:value forKey:key];
        }
    }

    return queryDictionary;
}

+ (NSString *)prettyJSONStringFromData:(NSData *)data {
    NSString *prettyString = nil;

    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        prettyString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:jsonObject options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding];
        // NSJSONSerialization escapes forward slashes. We want pretty json, so run through and unescape the slashes.
        prettyString = [prettyString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    } else {
        prettyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    return prettyString;
}

+ (BOOL)isValidJSONData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] ? YES : NO;
}

// Thanks to the following links for help with this method
// http://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
// https://github.com/nicklockwood/GZIP
+ (NSData *)inflatedDataFromCompressedData:(NSData *)compressedData {
    NSData *inflatedData = nil;
    NSUInteger compressedDataLength = [compressedData length];
    if (compressedDataLength > 0) {
        z_stream stream;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.avail_in = (uInt)compressedDataLength;
        stream.next_in = (void *)[compressedData bytes];
        stream.total_out = 0;
        stream.avail_out = 0;

        NSMutableData *mutableData = [NSMutableData dataWithLength:compressedDataLength * 1.5];
        if (inflateInit2(&stream, 15 + 32) == Z_OK) {
            int status = Z_OK;
            while (status == Z_OK) {
                if (stream.total_out >= [mutableData length]) {
                    mutableData.length += compressedDataLength / 2;
                }
                stream.next_out = (uint8_t *)[mutableData mutableBytes] + stream.total_out;
                stream.avail_out = (uInt)([mutableData length] - stream.total_out);
                status = inflate(&stream, Z_SYNC_FLUSH);
            }
            if (inflateEnd(&stream) == Z_OK) {
                if (status == Z_STREAM_END) {
                    mutableData.length = stream.total_out;
                    inflatedData = [mutableData copy];
                }
            }
        }
    }
    return inflatedData;
}

@end
