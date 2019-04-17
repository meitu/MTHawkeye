//
//  MTNetworkPerformanceTestViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 19/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MTNetworkPerformanceTestViewController.h"
#import <AFNetworking/AFNetworking.h>


@interface MTNetworkPerformanceTestViewController () <NSXMLParserDelegate>

@property (weak, nonatomic) IBOutlet UILabel *maxConcurrencyCountLabel;
@property (weak, nonatomic) IBOutlet UIStepper *maxConcurrencyCountStepper;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;

@property (strong, nonatomic) NSMutableString *logText;
@property (strong, nonatomic) NSMutableArray *imageUrls;

@property (weak, nonatomic) IBOutlet UISegmentedControl *primaryRequestSelector;
@property (weak, nonatomic) IBOutlet UISegmentedControl *batchRequestSelector;

@end


@implementation MTNetworkPerformanceTestViewController

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"


- (void)viewDidLoad {
    [super viewDidLoad];

    self.logText = [[NSMutableString alloc] init];
    self.logTextView.text = self.logText;
    self.maxConcurrencyCountStepper.value = [self.maxConcurrencyCountLabel.text integerValue];
    self.maxConcurrencyCountStepper.minimumValue = 1;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(doTestRequests)];
}

- (IBAction)maxConcurrencyCountStepperValueChange:(UIStepper *)sender {
    self.maxConcurrencyCountLabel.text = [NSString stringWithFormat:@"%@", @(sender.value)];
}

- (void)doTestRequests {
#if 1
    [self benchmarkWithSelectedMockWithCount:3
                                  completion:nil];
#else
    [self testFlickrImageDownloadTasks];
#endif
}

// MAKR: - Flickr Download Tasks
- (void)testFlickrImageDownloadTasks {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    NSURL *url = [NSURL URLWithString:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=05476dc1f835d1d07b78f2b19f2de809&is_commons=true&text=flower&per_page=50"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Accept"];

    AFXMLParserResponseSerializer *serializer = [AFXMLParserResponseSerializer serializer];
    serializer.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    [manager setResponseSerializer:serializer];

    NSURLSessionDataTask *task = [manager dataTaskWithRequest:request
                                            completionHandler:^(__unused NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
                                                if (error) {
                                                    [self.logText appendFormat:@">> flickr search error: %@", error];
                                                } else {
                                                    self.imageUrls = [NSMutableArray array];
                                                    ((NSXMLParser *)responseObject).delegate = self;
                                                    [responseObject parse];

                                                    if (((NSXMLParser *)responseObject).parserError != nil) {
                                                        [self.logText appendFormat:@">> flickr search result parse error: %@", ((NSXMLParser *)responseObject).parserError];
                                                    } else {
                                                        [self downloadImages:self.imageUrls];
                                                    }
                                                }
                                                self.logTextView.text = self.logText;
                                            }];
    [task resume];
}

- (void)downloadImages:(NSArray *)urlStrings {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = [self.maxConcurrencyCountLabel.text integerValue];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];

    NSInteger i = 0;
    __block NSUInteger count = 0;
    __block uint64_t totalWrittenSize = 0;
    NSDate *start = [NSDate date];
    [self.logText appendFormat:@">>>> start ["];

    for (NSString *urlString in urlStrings) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSURLSessionDownloadTask *task = [manager
            downloadTaskWithRequest:request
            progress:nil
            destination:^NSURL *_Nonnull(__unused NSURL *_Nonnull targetPath, NSURLResponse *_Nonnull response) {
                NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
                return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
            }
            completionHandler:^(__unused NSURLResponse *_Nonnull response, __unused NSURL *_Nullable filePath, __unused NSError *_Nullable error) {
                [self.logText appendFormat:@"%@, ", @(i)];
                self.logTextView.text = self.logText;

                count++;
                if (count >= urlStrings.count) {
                    NSTimeInterval duration = -[start timeIntervalSinceDate:[NSDate date]];
                    [self.logText appendFormat:@"] end \n Duration: %.3fs, %f.3Kb\n\n", duration, totalWrittenSize / 1024.f];
                    self.logTextView.text = self.logText;

                    NSLog(@"%@", self.logText);
                }
            }];
        [task resume];
        i++;
    }
}

// MARK: - Mock request tasks
- (void)benchmarkWithSelectedMockWithCount:(NSInteger)count completion:(void (^)(void))completion {
    NSInteger selectedPrimaryMock = self.primaryRequestSelector.selectedSegmentIndex;
    NSInteger maxConcurrency = [self.maxConcurrencyCountLabel.text integerValue];
    NSInteger selectedBatchMock = self.batchRequestSelector.selectedSegmentIndex;

    [self.logText appendFormat:@">> {{%@}} ", @(maxConcurrency)];
    self.logTextView.text = self.logText;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        __block double primaryDuration = 0.f;
        __block double totalDuration = 0.f;
        for (NSInteger i = 0; i < count; ++i) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self runTestWithPrimaryIndex:selectedPrimaryMock
                               batchIndex:selectedBatchMock
                           maxConcurrency:maxConcurrency
                               completion:^(double inPrimaryDuration, double inTotalDuration) {
                                   primaryDuration += inPrimaryDuration;
                                   totalDuration += inTotalDuration;
                                   dispatch_semaphore_signal(semaphore);
                               }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            double primaryDurationAverage = primaryDuration / count;
            double totalDurationAverage = totalDuration / count;

            double primaryTraffic = [self downloadTrafficForMockIndex:selectedPrimaryMock];
            double totalTraffic = [self batchDownloadTrafficForMockIndex:selectedBatchMock] + primaryTraffic;
            double totalVelocity = totalTraffic / totalDurationAverage;
            double primaryVelocity = primaryTraffic / primaryDurationAverage;
            NSString *allInfo = [NSString stringWithFormat:@"whole: %.2fKB, %.3fs, %.2fKB/s", totalTraffic, totalDurationAverage, totalVelocity];
            NSString *primaryInfo = [NSString stringWithFormat:@"primary: %.2fKB, %.3fs, %.2fKB/s", primaryTraffic, primaryDurationAverage, primaryVelocity];
            [self.logText appendFormat:@"%@ \n %@ \n\n", allInfo, primaryInfo];

            self.logTextView.text = self.logText;
            NSLog(@"%@", self.logText);

            if (completion) {
                completion();
            }
        });
    });
}

- (void)benchmarkOnceWithSelectedPrimary:(__unused NSInteger)primaryRequestMockIndex
                              batchIndex:(__unused NSInteger)batchRequestMockIndex
                          maxConcurrency:(__unused NSInteger)maxConcurrency
                              completion:(__unused void (^)(double totalTraffic, double totalDuration))completion {
}

- (void)runTestWithPrimaryIndex:(NSInteger)primaryRequestMockIndex
                     batchIndex:(NSInteger)batchRequestMockIndex
                 maxConcurrency:(NSInteger)maxConcurrency
                     completion:(void (^)(double primaryDuration, double totalDuration))completion {
    //
    // 模拟一个关键请求，此处没有设置优先级，用于暴露未设置优先级可能导致的问题
    //

    NSString *primaryFetchUrlString = [self mockRequestUrlStringForMockIndex:primaryRequestMockIndex].lastObject;

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = maxConcurrency;
    configuration.URLCache = nil;
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];

    NSDate *start = [NSDate date];
    __block NSTimeInterval primaryRequestDuration;

    NSURLRequest *primaryRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:primaryFetchUrlString]];
    NSURLSessionTask *primaryTask = [manager dataTaskWithRequest:primaryRequest
                                               completionHandler:^(__unused NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
                                                   primaryRequestDuration = -[start timeIntervalSinceDate:[NSDate date]];
                                                   NSLog(@"primary completed");
                                               }];
    [primaryTask resume];


    //
    // 模拟在关键请求发出的同时，有其他次要的一组请求
    // 这组请求可能影响 primaryRequest 的速度
    //
    NSArray *batchFetchUrlStrings = [self mockRequestUrlStringForMockIndex:batchRequestMockIndex];
    __block NSUInteger guard = 0;
    for (NSUInteger i = 0; i < batchFetchUrlStrings.count; ++i) {
        NSString *url = batchFetchUrlStrings[i];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        NSURLSessionTask *task = [manager
            dataTaskWithRequest:request
              completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
                  guard++;
                  if (guard == batchFetchUrlStrings.count) {
                      NSTimeInterval duration = -[start timeIntervalSinceDate:[NSDate date]];
                      completion(primaryRequestDuration, duration);
                  }
                  NSLog(@"batch %@ completed", @(i));
              }];
        [task resume];
    }
}

- (NSArray *)mockRequestUrlStringForMockIndex:(NSInteger)mockIndex {
    if (mockIndex == 0) {
        return [self mockResponse0];
    } else if (mockIndex == 1) {
        return [self mockResponse1];
    } else if (mockIndex == 2) {
        return [self mockResponse2];
    } else if (mockIndex == 3) {
        return [self mockResponse3];
    }
    return nil;
}

- (double)batchDownloadTrafficForMockIndex:(NSInteger)mockBatchIndex {
    return [self downloadTrafficForMockIndex:mockBatchIndex];
}

- (double)downloadTrafficForMockIndex:(NSInteger)mockIndex {
    if (mockIndex == 0) {
        return 271 / 1024.f;
    } else if (mockIndex == 1) {
        return 1.2;
    } else if (mockIndex == 2) {
        return 19.1;
    } else if (mockIndex == 3) {
        return 63.2;
    }
    return 0;
}

- (NSArray *)mockResponse0 {
    // 271B * 10
    return @[
        @"http://api.test.meitu.com/makeup/ios_test/a_1.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_2.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_3.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_4.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_5.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_6.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_7.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_8.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_9.json",
        @"http://api.test.meitu.com/makeup/ios_test/a_10.json",
    ];
}

- (NSArray *)mockResponse1 {
    // 1.2KB * 10
    return @[
        @"http://api.test.meitu.com/makeup/ios_test/b_1.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_2.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_3.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_4.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_5.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_6.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_7.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_8.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_9.json",
        @"http://api.test.meitu.com/makeup/ios_test/b_10.json",
    ];
}

- (NSArray *)mockResponse2 {
    // 19.1KB * 10
    return @[
        @"http://api.test.meitu.com/makeup/ios_test/c_1.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_2.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_3.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_4.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_5.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_6.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_7.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_8.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_9.json",
        @"http://api.test.meitu.com/makeup/ios_test/c_10.json",
    ];
}

- (NSArray *)mockResponse3 {
    // 63.2KB * 10
    return @[
        @"http://api.test.meitu.com/makeup/ios_test/d_1.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_2.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_3.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_4.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_5.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_6.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_7.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_8.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_9.json",
        @"http://api.test.meitu.com/makeup/ios_test/d_10.json",
    ];
}

#pragma mark NSXMLParser Parsing Callbacks

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"photo"]) {
        NSString *photoId = [attributeDict objectForKey:@"id"];
        NSString *secret = [attributeDict objectForKey:@"secret"];
        NSString *server = [attributeDict objectForKey:@"server"];
        NSString *farm = [attributeDict objectForKey:@"farm"];

        // add url string to self.imageUrls
        NSString *urlString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_z.jpg", farm, server, photoId, secret];
        [self.imageUrls addObject:urlString];
    }
}

#pragma clang diagnostic pop

@end
