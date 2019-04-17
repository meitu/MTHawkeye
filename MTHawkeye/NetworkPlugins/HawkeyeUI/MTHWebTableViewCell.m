//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 20/08/2018
// Created by: Huni
//


#import "MTHWebTableViewCell.h"

#import <MTHawkeye/MTHUISkeletonUtility.h>
#import <WebKit/WebKit.h>

NSString *const kMTHawkeyeWebTableViewCellIdentifier = @"kMTHawkeyeWebTableViewCellIdentifier";

@interface MTHWebTableViewCell ()

@property (nonatomic, strong) WKWebView *webView;

@end

@implementation MTHWebTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
    }
    return self;
}

- (WKWebView *)webView {
    if (!_webView) {
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(8, 0, self.frame.size.width - 16, self.frame.size.height)];
        _webView.scrollView.bounces = NO;
        [self addSubview:_webView];
    }
    return _webView;
}

- (void)webViewLoadString:(NSString *)string {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *htmlString = [NSString stringWithFormat:@"<head><meta name='viewport' content='initial-scale=1.0'></head><body><pre>%@</pre></body>", [MTHUISkeletonUtility stringByEscapingHTMLEntitiesInString:string]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.webView loadHTMLString:htmlString baseURL:nil];
        });
    });
}

@end
