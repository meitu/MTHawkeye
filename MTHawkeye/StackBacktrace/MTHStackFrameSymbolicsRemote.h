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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHStackFrameSymbolicsRemote : NSObject

/*
 MTHStackFrameSymbolicsRemoteProtocol

 As a symbolics service, you should accept a POST request with a JSON format string HTTP body.

    eg:

 ```json
 {
     "dyld_images_info": {
         "arch": "arm64 v8",
         "model": "16B92",
         "os_version": "12.1",
         "name": "Meipai",
         "dyld_images": [
             {
                 "addr":"0x1002034",         # require
                 "addr_slide":"0x002132",    # optional
                 "uuid":"23024352u5982752",  # require
                 "name":""                   # optional
             }, ...
         ]
     },
     "stack_frames": [
         "0x18ee92708",
         "0x18ee92722",
         "0x18ee92333",
         "0x18ee92221",
         "0x18ee92998"
     ]
 }
 ```

 and response symbolicated stack frames in JSON format string.

    eg:

 ```json
 {
     "stack_frames":[
         {
             "addr": "0x1002034",         # require
             "fname": "Meipai",           # require, path name of shared object.
             "fbase": "0x1001000",        # optional, base address of shared object.
             "sname": "[AClass method1]", # require, name of nearest symbol.
             "sbase": "0x1002034",        # optional, address of nearest symbol.
         }, ...
     ],
     "error":{ # optional
         "msg": ""
     }
 }
 ```

 */
+ (NSString *)symbolicsServerURL;
+ (void)configureSymbolicsServerURL:(NSString *)serverURL;
+ (void)configureSymbolicsTaskTimeout:(NSTimeInterval)timeoutInSeconds;

/*
 @param framePointers stack frames that needs to be symbolized, in hexadecimal string array format.
    eg. @[@"0x100000", @"0x10000230"]

 @param dyldImagesInfo associated dyld images information.

    eg. @{
            "arch": "arm64 v8",
            "model": "16B92",
            "os_version": "12.1",
            "name": "ProjectName",
            "dyld_images": [
                {
                     "addr": "0x1000240",
                     "addr_slide": "0x0240",
                     "uuid": "xxxxxxxxxxxxxxx",
                     "name": "xyx"  # optional
                },
                {
                    "addr": "0x1000240",
                    "addr_slide": "0x0240",
                    "uuid": "xxxxxxxxxxxxxxx"
                }
            ]
        }

 @param completionHandler get the symbolized frames from completionHandler

    eg. @[
            {
                "addr": "0x1000240",
                "fname": "xyx",
                "fbase": "0x1000100",
                "sname": "[AClass method1]",
                "sbase": "0x1000240"
            }, ...
        ]

 */
+ (void)symbolizeStackFrames:(NSArray<NSString *> *)framePointers
         withDyldImagesInfos:(NSDictionary *)dyldImagesInfo
           completionHandler:(void (^)(NSArray<NSDictionary<NSString *, NSString *> *> *symbolizedFrames, NSError *error))completionHandler;

@end

NS_ASSUME_NONNULL_END
