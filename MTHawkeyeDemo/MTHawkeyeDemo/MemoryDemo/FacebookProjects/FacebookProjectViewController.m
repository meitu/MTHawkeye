//
//  FacebookProjectViewController.m
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import "FacebookProjectViewController.h"
#import <WebKit/WKWebView.h>

@interface FacebookProjectViewController () <CAAnimationDelegate>

@end

@implementation FacebookProjectViewController {
    // Warning, Memory Leak: it should be weak!
    id _delegate;

    WKWebView *_webView;
    NSURL *_url;
}

- (instancetype)initWithName:(NSString *)name URL:(NSURL *)url {
    if (self = [super init]) {
        self.title = name;
        _url = url;

        // Warning, Memory Leak: Intentional retain cycle
        _delegate = self;
    }

    return self;
}

- (void)dealloc {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)loadView {
    _webView = [[WKWebView alloc] init];
    self.view = _webView;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [_webView loadRequest:[NSURLRequest requestWithURL:_url]];

    CABasicAnimation *scaleLargeAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleLargeAnim.fromValue = @(1.f);
    scaleLargeAnim.toValue = @(1.f);
    scaleLargeAnim.removedOnCompletion = NO;
    scaleLargeAnim.fillMode = kCAFillModeForwards;
    scaleLargeAnim.duration = 0.3f;
    scaleLargeAnim.delegate = self; // Warning, Memory Leak: strong retain
    [self.view.layer addAnimation:scaleLargeAnim forKey:@"scaleLargeAnim"];

    UIView *subview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    CALayer *sublayer1 = [[CALayer alloc] init];
    CALayer *sublayer2 = [[CALayer alloc] init];
    [subview.layer addSublayer:sublayer1];
    [subview.layer addSublayer:sublayer2];
    [self.view addSubview:subview];

    CABasicAnimation *anim2 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    anim2.fromValue = @(1.f);
    anim2.toValue = @(1.f);
    anim2.removedOnCompletion = NO;
    anim2.fillMode = kCAFillModeForwards;
    anim2.duration = 0.3f;
    anim2.delegate = self; // Warning, Memory Leak: strong retain
    [sublayer1 addAnimation:anim2 forKey:@"anim2"];

    CABasicAnimation *anim3 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    anim3.fromValue = @(1.f);
    anim3.toValue = @(1.f);
    anim3.removedOnCompletion = NO;
    anim3.fillMode = kCAFillModeForwards;
    anim3.duration = 0.3f;
    anim3.delegate = self; // Warning, Memory Leak: strong retain
    [sublayer2 addAnimation:anim3 forKey:@"anim3"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

@end
