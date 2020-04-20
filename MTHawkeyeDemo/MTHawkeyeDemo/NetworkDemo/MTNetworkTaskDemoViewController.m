//
//  MTNetworkTaskDemoViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 17/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MTNetworkTaskDemoViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <MTHDirectoryWatcher.h>


@interface MTNetworkTaskDemoViewController () <NSURLSessionDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *clearLogBtn;
@property (nonatomic, strong) UIButton *clearCacheBtn;

@property (nonatomic, strong) NSMutableString *log;

@end

@implementation MTNetworkTaskDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.textView = [[UITextView alloc] init];
    self.textView.editable = NO;
    self.view = self.textView;

    self.clearLogBtn = [[UIButton alloc] init];
    [self.clearLogBtn setTitle:@"clear log" forState:UIControlStateNormal];
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    self.clearLogBtn.frame = CGRectMake(width - 90, 10, 90, 30);
    [self.clearLogBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.clearLogBtn addTarget:self action:@selector(clearLogBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearLogBtn];

    self.clearCacheBtn = [[UIButton alloc] init];
    [self.clearCacheBtn setTitle:@"clear cache" forState:UIControlStateNormal];
    self.clearCacheBtn.frame = CGRectMake(width - 100, 50, 100, 30);
    [self.clearCacheBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.clearCacheBtn addTarget:self action:@selector(clearCacheBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearCacheBtn];

    self.log = [NSMutableString string];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(fireRequestTask)];

    //    [self testCrash];
}


- (void)testCrash {
    AFHTTPRequestSerializer *ser = [[AFHTTPRequestSerializer alloc] init];
    while (1) {
        NSMutableURLRequest *request = [ser requestWithMethod:@"GET" URLString:@"a-url" parameters:nil error:nil];

        // iOS's internal HTTP parser finalization code is not thread safe, and can
        // result in a double free crash.
        // This workaround finalizes the parser before we hand-off the request to
        // NSURLSession, ensuring that other threads inspecting the request do not
        // trigger a race to finalize the parser.
        // https://github.com/AFNetworking/AFNetworking/issues/2334

        // Uncomment next line to fix crash.
        [request HTTPBody];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [request HTTPBody];
        });

        [request HTTPBody];
    }
}

- (void)clearLogBtnTapped {
    self.log = [NSMutableString string];
    self.textView.text = self.log;
}

- (void)clearCacheBtnTapped {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)fireRequestTask {
    NSArray *mockRequest = @[
        @"https://www.meitu.com/",
        @"https://weibo.com/",
        @"https://www.github.com/",
        @"https://www.apple.com/",
        @"https://www.google.com/",
        @"https://ww.im-not-exist.com/",
        @"http://t.cn/EMis3Ec", // jpg image
    ];

    NSInteger requestCount = arc4random() % 5 + 1;
    for (NSInteger i = 0; i < requestCount; ++i) {
        NSInteger index = arc4random() % mockRequest.count;
        NSURL *radomRequestURL = [NSURL URLWithString:mockRequest[index]];

        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [manager.requestSerializer setValue:@"test-value" forHTTPHeaderField:@"custom-http-field"];
        [manager GET:mockRequest[index] parameters:@{@"custom-key" : @"custom-value"} headers:nil progress:nil success:nil failure:nil];

        [self.log appendFormat:@">> %@ \n", radomRequestURL];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            self.textView.text = self.log;
        });
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didReceiveResponse:(nonnull NSURLResponse *)response completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"<< [%@] %@", @(((NSHTTPURLResponse *)response).statusCode), response.URL);
}

@end
