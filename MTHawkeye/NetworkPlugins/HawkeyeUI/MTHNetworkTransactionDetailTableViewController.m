//
// Copyright (c) 2014-2016, Flipboard
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2/10/15
// Created by: Ryan Olson
//


#import "MTHNetworkTransactionDetailTableViewController.h"
#import "MTHMultilineTableViewCell.h"
#import "MTHNetworkCurlLogger.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "MTHNetworkTransactionAdviceDetailViewController.h"
#import "MTHPopoverViewController.h"
#import "MTHWebTableViewCell.h"
#import "MTHawkeyeWebViewController.h"

#import <CoreText/CoreText.h>
#import <FLEX/FLEXImagePreviewViewController.h>
#import <MTHawkeye/MTHUISkeletonUtility.h>


typedef NS_ENUM(NSInteger, MTHawkeyeNetworkDetailRowStyle) {
    MTHawkeyeNetworkDetailRowDefault = 0,
    MTHawkeyeNetworkDetailRowWebView
};

static const NSInteger kMaxLimitedBody = 1024;

@interface MTHawkeyeNetworkDetailSection : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray *rows;

@end

@implementation MTHawkeyeNetworkDetailSection

@end

typedef UIViewController * (^MTHawkeyeNetworkDetailRowSelectionFuture)(void);

@interface MTHawkeyeNetworkDetailRow : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detailText;
@property (nonatomic, strong) MTHNetworkTaskAdvice *advice;
@property (nonatomic, copy) MTHawkeyeNetworkDetailRowSelectionFuture selectionFuture;
@property (nonatomic, assign) MTHawkeyeNetworkDetailRowStyle style;

@end

@implementation MTHawkeyeNetworkDetailRow

@end

@interface MTHNetworkTransactionDetailTableViewController () <MTHNetworkRecorderDelegate>

@property (nonatomic, copy) NSArray *sections;

@end

@implementation MTHNetworkTransactionDetailTableViewController

- (void)dealloc {
    [[MTHNetworkRecorder defaultRecorder] removeDelegate:self];
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    // Force grouped style
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[MTHNetworkRecorder defaultRecorder] addDelegate:self];

    [self rebuildTableSections];

    [self.tableView registerClass:[MTHMultilineTableViewCell class] forCellReuseIdentifier:kMTHawkeyeMultilineTableViewCellIdentifier];
    [self.tableView registerClass:[MTHWebTableViewCell class] forCellReuseIdentifier:kMTHawkeyeWebTableViewCellIdentifier];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionBtnTapped:)];
}

- (void)setTransaction:(MTHNetworkTransaction *)transaction {
    if (![_transaction isEqual:transaction]) {
        _transaction = transaction;
        self.title = [NSString stringWithFormat:@"%@: %@", @(transaction.requestIndex), [transaction.request.URL lastPathComponent]];
    }
}

- (void)setSections:(NSArray *)sections {
    if (![_sections isEqual:sections]) {
        _sections = [sections copy];
        [self.tableView reloadData];
    }
}

- (void)rebuildTableSections {
    NSMutableArray *sections = [NSMutableArray array];

    NSArray<MTHNetworkTaskAdvice *> *advices = self.advices;
    MTHawkeyeNetworkDetailSection *advicesSection = [[self class] transactionAdviceSectionForAdvices:advices];
    if (advicesSection && advicesSection.rows.count > 0) {
        [sections addObject:advicesSection];
    }
    MTHawkeyeNetworkDetailSection *generalSection = [[self class] generalSectionForTransaction:self.transaction];
    if ([generalSection.rows count] > 0) {
        [sections addObject:generalSection];
    }

    MTHawkeyeNetworkDetailSection *requestHeadersSection = [[self class] requestHeadersSectionForTransaction:self.transaction];
    if ([requestHeadersSection.rows count] > 0) {
        [sections addObject:requestHeadersSection];
    }
    MTHawkeyeNetworkDetailSection *postBodySection = [[self class] postBodySectionForTransaction:self.transaction];
    if ([postBodySection.rows count] > 0) {
        [sections addObject:postBodySection];
    }
    MTHawkeyeNetworkDetailSection *responseHeadersSection = [[self class] responseHeadersSectionForTransaction:self.transaction];
    if ([responseHeadersSection.rows count] > 0) {
        [sections addObject:responseHeadersSection];
    }
    MTHawkeyeNetworkDetailSection *reponseBodySection = [[self class] responseBodySectionForTransaction:self.transaction];
    if ([reponseBodySection.rows count] > 0) {
        [sections addObject:reponseBodySection];
    }

    self.sections = sections;
}

- (void)presentViewControllerInPopover:(UIViewController *)viewController {
    MTHPopoverViewController *popoverVC = [[MTHPopoverViewController alloc] initWithContentViewController:viewController fromSourceView:self.view];
    // 设为系统默认样式
    [popoverVC.navigationBar setBarTintColor:nil];
    [popoverVC.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [popoverVC.navigationBar setShadowImage:nil];
    [popoverVC.navigationBar setTitleTextAttributes:nil];
    [self presentViewController:popoverVC animated:YES completion:nil];
}

- (void)actionBtnTapped:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *curlString = [MTHNetworkCurlLogger curlCommandString:_transaction.request];
    NSMutableString *allDetailString = [NSMutableString stringWithFormat:@"# %@\n", self.title];
    for (MTHawkeyeNetworkDetailSection *section in self.sections) {
        [allDetailString appendFormat:@"\n## %@\n", section.title];
        for (MTHawkeyeNetworkDetailRow *row in section.rows) {
            [allDetailString appendFormat:@"* %@:   %@\n", row.title, row.detailText];
        }
    }
    UIAlertAction *copyURLaction = [UIAlertAction actionWithTitle:@"Copy curl"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              [[UIPasteboard generalPasteboard] setString:curlString];
                                                          }];
    UIAlertAction *copyAllAction = [UIAlertAction actionWithTitle:@"Copy all detail"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              [[UIPasteboard generalPasteboard] setString:[allDetailString copy]];
                                                          }];
    UIAlertAction *airDropAction = [UIAlertAction actionWithTitle:@"AirDrop all detail"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              UIActivityViewController *airDropVC = [[UIActivityViewController alloc] initWithActivityItems:@[ curlString, allDetailString ] applicationActivities:nil];
                                                              [self presentViewController:airDropVC animated:YES completion:nil];
                                                          }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:copyURLaction];
    [alertController addAction:copyAllAction];
    [alertController addAction:airDropAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    MTHawkeyeNetworkDetailSection *sectionModel = self.sections[section];
    return [sectionModel.rows count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    MTHawkeyeNetworkDetailSection *sectionModel = self.sections[section];
    return sectionModel.title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    MTHawkeyeNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

    if (rowModel.style == MTHawkeyeNetworkDetailRowWebView) {
        MTHWebTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMTHawkeyeWebTableViewCellIdentifier forIndexPath:indexPath];
        [cell webViewLoadString:rowModel.detailText];
        return cell;
    } else {
        MTHMultilineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMTHawkeyeMultilineTableViewCellIdentifier forIndexPath:indexPath];
        cell.textLabel.attributedText = [[self class] attributedTextForRow:rowModel];
        cell.accessoryType = rowModel.selectionFuture ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        cell.selectionStyle = rowModel.selectionFuture ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

    UIViewController *viewControllerToPush = nil;
    if (rowModel.selectionFuture) {
        viewControllerToPush = rowModel.selectionFuture();
    }

    if (viewControllerToPush) {
        if ([viewControllerToPush isMemberOfClass:[MTHNetworkTransactionAdviceDetailViewController class]]
            && ![self.navigationController isKindOfClass:[MTHPopoverViewController class]]) {
            [self presentViewControllerInPopover:viewControllerToPush];
        } else {
            [self.navigationController pushViewController:viewControllerToPush animated:YES];
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
    NSAttributedString *attributedText = [[self class] attributedTextForRow:row];
    if (row.style == MTHawkeyeNetworkDetailRowDefault) {
        BOOL showsAccessory = row.selectionFuture != nil;
        return [MTHMultilineTableViewCell preferredHeightWithAttributedText:attributedText inTableViewWidth:self.tableView.bounds.size.width style:UITableViewStyleGrouped showsAccessory:showsAccessory];
    } else {
        NSString *title = row.title ? [NSString stringWithFormat:@"%@: ", row.title] : @"";
        NSString *detailText = row.detailText ?: @"";
        NSString *htmlString = [NSString stringWithFormat:@"<head><meta name='viewport' content='initial-scale=1.0'></head><body><pre>%@</pre></body>", [MTHUISkeletonUtility stringByEscapingHTMLEntitiesInString:[title stringByAppendingString:detailText]]];
        NSInteger count = 0;
        for (int i = 0; i < htmlString.length; i++) {
            if ([[htmlString substringWithRange:NSMakeRange(i, 1)] isEqualToString:@"\n"]) {
                count += 1;
            }
        }
        return count ? count * ([MTHUISkeletonUtility defaultTableViewCellLabelFont].pointSize + 3) + 20.0 : 26.0;
    }
}

- (MTHawkeyeNetworkDetailRow *)rowModelAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeNetworkDetailSection *sectionModel = self.sections[indexPath.section];
    return sectionModel.rows[indexPath.row];
}

#pragma mark - Cell Copying

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        MTHawkeyeNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
        [[UIPasteboard generalPasteboard] setString:row.detailText];
    }
}

#pragma mark - View Configuration

+ (NSAttributedString *)attributedTextForRow:(MTHawkeyeNetworkDetailRow *)row {
    UIColor *titleColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    if (row.advice) {
        switch (row.advice.level) {
            case MTHNetworkTaskAdviceLevelHigh:
                titleColor = [UIColor colorWithRed:0.816 green:0.00784 blue:0.106 alpha:1];
                break;
            case MTHNetworkTaskAdviceLevelMiddle:
                titleColor = [UIColor colorWithRed:1 green:0.455 blue:0.455 alpha:1];
                break;
            case MTHNetworkTaskAdviceLevelLow:
                titleColor = [UIColor colorWithWhite:0.533 alpha:1];
                break;
        }
    }
    NSDictionary *titleAttributes = @{
        NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:12.0],
        NSForegroundColorAttributeName : titleColor
    };
    NSDictionary *detailAttributes = @{
        NSFontAttributeName : [MTHUISkeletonUtility defaultTableViewCellLabelFont],
        NSForegroundColorAttributeName : [UIColor blackColor]
    };

    NSString *title = row.title ? [NSString stringWithFormat:@"%@: ", row.title] : @"";
    NSString *detailText = row.detailText ?: @"";
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:titleAttributes]];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:detailText attributes:detailAttributes]];

    return attributedText;
}

/****************************************************************************/
#pragma mark - MTHNetworkRecorderDelegate

- (void)recorderWantCacheTransactionAsUpdated:(MTHNetworkTransaction *)transaction currentState:(MTHNetworkTransactionState)state {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if (transaction == self.transaction) {
            [self rebuildTableSections];
        }
    });
}

#pragma mark - Table Data Generation

+ (MTHawkeyeNetworkDetailSection *)transactionAdviceSectionForAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices {
    if (advices.count == 0) {
        return nil;
    }

    NSMutableArray<MTHawkeyeNetworkDetailRow *> *rows = [NSMutableArray arrayWithCapacity:advices.count];
    for (MTHNetworkTaskAdvice *advice in advices) {
        MTHawkeyeNetworkDetailRow *requestURLRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        requestURLRow.title = [advice levelText];
        requestURLRow.detailText = advice.adviceTitleText;
        requestURLRow.advice = advice;
        requestURLRow.selectionFuture = ^{
            MTHNetworkTransactionAdviceDetailViewController *adviceVC = [[MTHNetworkTransactionAdviceDetailViewController alloc] init];
            adviceVC.advice = advice;
            return adviceVC;
        };
        [rows addObject:requestURLRow];
    }

    MTHawkeyeNetworkDetailSection *adviceSection = [[MTHawkeyeNetworkDetailSection alloc] init];
    adviceSection.title = @"Advice";
    adviceSection.rows = rows;

    return adviceSection;
}

+ (MTHawkeyeNetworkDetailSection *)generalSectionForTransaction:(MTHNetworkTransaction *)transaction {
    NSMutableArray *rows = [NSMutableArray array];

    MTHawkeyeNetworkDetailRow *requestURLRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    requestURLRow.title = @"Request URL";
    NSURL *url = transaction.request.URL;
    requestURLRow.detailText = url.absoluteString;
    requestURLRow.selectionFuture = ^{
        UIViewController *urlWebViewController = [[MTHawkeyeWebViewController alloc] initWithURL:url];
        urlWebViewController.title = url.absoluteString;
        return urlWebViewController;
    };
    [rows addObject:requestURLRow];

    MTHawkeyeNetworkDetailRow *requestMethodRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    requestMethodRow.title = @"Request Method";
    requestMethodRow.detailText = transaction.request.HTTPMethod;
    [rows addObject:requestMethodRow];

    NSString *statusCodeString = [MTHUISkeletonUtility statusCodeStringFromURLResponse:transaction.response];
    if ([statusCodeString length] > 0) {
        MTHawkeyeNetworkDetailRow *statusCodeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        statusCodeRow.title = @"Status Code";
        statusCodeRow.detailText = statusCodeString;
        [rows addObject:statusCodeRow];
    }

    if (transaction.error) {
        MTHawkeyeNetworkDetailRow *errorRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        errorRow.title = @"Error";
        errorRow.detailText = transaction.error.localizedDescription;
        [rows addObject:errorRow];
    }

    MTHawkeyeNetworkDetailRow *resquestSizeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    resquestSizeRow.title = @"Resquest Size";
    resquestSizeRow.detailText = [NSByteCountFormatter stringFromByteCount:transaction.requestLength countStyle:NSByteCountFormatterCountStyleBinary];
    [rows addObject:resquestSizeRow];

    MTHawkeyeNetworkDetailRow *responseSizeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    responseSizeRow.title = @"Response Size";
    responseSizeRow.detailText = [NSByteCountFormatter stringFromByteCount:transaction.responseLength countStyle:NSByteCountFormatterCountStyleBinary];
    [rows addObject:responseSizeRow];

    MTHawkeyeNetworkDetailRow *mimeTypeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    mimeTypeRow.title = @"MIME Type";
    mimeTypeRow.detailText = transaction.response.MIMEType;
    [rows addObject:mimeTypeRow];

    MTHawkeyeNetworkDetailRow *mechanismRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    mechanismRow.title = @"Mechanism";
    mechanismRow.detailText = transaction.requestMechanism;
    [rows addObject:mechanismRow];

    NSDateFormatter *startTimeFormatter = [[NSDateFormatter alloc] init];
    startTimeFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

    MTHawkeyeNetworkDetailRow *localStartTimeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    localStartTimeRow.title = [NSString stringWithFormat:@"Start Time (%@)", [[NSTimeZone localTimeZone] abbreviationForDate:transaction.startTime]];
    localStartTimeRow.detailText = [startTimeFormatter stringFromDate:transaction.startTime];
    [rows addObject:localStartTimeRow];

    startTimeFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

    MTHawkeyeNetworkDetailRow *utcStartTimeRow = [[MTHawkeyeNetworkDetailRow alloc] init];
    utcStartTimeRow.title = @"Start Time (UTC)";
    utcStartTimeRow.detailText = [startTimeFormatter stringFromDate:transaction.startTime];
    [rows addObject:utcStartTimeRow];

    MTHawkeyeNetworkDetailRow *unixStartTime = [[MTHawkeyeNetworkDetailRow alloc] init];
    unixStartTime.title = @"Unix Start Time";
    unixStartTime.detailText = [NSString stringWithFormat:@"%f", [transaction.startTime timeIntervalSince1970]];
    [rows addObject:unixStartTime];


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

    if (transaction.useURLSessionTaskMetrics) {
        MTHawkeyeNetworkDetailRow *durationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        durationRow.title = @"Total Duration";
        durationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:transaction.duration];
        [rows addObject:durationRow];

        NSDate *thisTurnTransMetricsStartFrom = transaction.startTime;
        NSInteger index = 0;
        for (NSURLSessionTaskTransactionMetrics *transMetrics in transaction.taskMetrics.transactionMetrics) {
            if (index++ == 0) {
                NSTimeInterval beforeStartDuration = [transMetrics.fetchStartDate timeIntervalSinceDate:transaction.startTime];
                if (beforeStartDuration > 0.005f) {
                    MTHawkeyeNetworkDetailRow *durationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                    durationRow.title = @"Before First StartFetch";
                    durationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:beforeStartDuration];
                    [rows addObject:durationRow];
                }
            }

            if (transMetrics.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache) {
                MTHawkeyeNetworkDetailRow *localCacheFetchRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                localCacheFetchRow.title = @"Local Cache Fetch";
                NSTimeInterval localFetchDuration = [transMetrics.responseEndDate timeIntervalSinceDate:transMetrics.fetchStartDate];
                localCacheFetchRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:localFetchDuration];
                [rows addObject:localCacheFetchRow];

                thisTurnTransMetricsStartFrom = transMetrics.responseEndDate;
                continue;
            }
            NSTimeInterval dnsDuration = [transMetrics.domainLookupEndDate timeIntervalSinceDate:transMetrics.domainLookupStartDate];
            NSTimeInterval connDuration = [transMetrics.connectEndDate timeIntervalSinceDate:transMetrics.connectStartDate];
            NSTimeInterval secConnDuration = [transMetrics.secureConnectionEndDate timeIntervalSinceDate:transMetrics.secureConnectionStartDate];
            NSTimeInterval transDuration = [transMetrics.responseEndDate timeIntervalSinceDate:transMetrics.requestStartDate];

            NSTimeInterval queueingDuration = 0;
            if (transMetrics.domainLookupStartDate) {
                queueingDuration = [transMetrics.domainLookupStartDate timeIntervalSinceDate:thisTurnTransMetricsStartFrom];
            } else if (transMetrics.connectStartDate) {
                queueingDuration = [transMetrics.connectStartDate timeIntervalSinceDate:thisTurnTransMetricsStartFrom];
            } else if (transMetrics.requestStartDate) {
                queueingDuration = [transMetrics.requestStartDate timeIntervalSinceDate:thisTurnTransMetricsStartFrom];
            }
            if (queueingDuration > 0.005f) {
                MTHawkeyeNetworkDetailRow *durationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                durationRow.title = @"Queueing";
                durationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:queueingDuration];
                [rows addObject:durationRow];
            }

            if (dnsDuration > 0.f) {
                MTHawkeyeNetworkDetailRow *dnsDurationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                dnsDurationRow.title = @"DNS";
                dnsDurationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:dnsDuration];
                [rows addObject:dnsDurationRow];
            }

            if (connDuration > 0.f) {
                MTHawkeyeNetworkDetailRow *connDurationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                NSString *connDurText = [MTHUISkeletonUtility stringFromRequestDuration:connDuration];
                if (secConnDuration > 0.f) {
                    connDurationRow.title = (secConnDuration > 0.f) ? @"Connection" : @"Connection (Secure Conn)";
                    NSString *secureConnDurText = [MTHUISkeletonUtility stringFromRequestDuration:secConnDuration];
                    connDurationRow.detailText = [NSString stringWithFormat:@"%@ (%@)", connDurText, secureConnDurText];
                } else {
                    connDurationRow.title = @"Connection";
                    connDurationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:connDuration];
                }
                [rows addObject:connDurationRow];
            }

            if (transDuration > 0.f) {
                MTHawkeyeNetworkDetailRow *transDurationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
                transDurationRow.title = @"Request/Response";
                transDurationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:transDuration];
                [rows addObject:transDurationRow];
            }

            if (transMetrics.responseEndDate) {
                thisTurnTransMetricsStartFrom = transMetrics.responseEndDate;
            }
        }
    } else {
        MTHawkeyeNetworkDetailRow *durationRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        durationRow.title = @"Total Duration";
        durationRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:transaction.duration];
        [rows addObject:durationRow];

        MTHawkeyeNetworkDetailRow *latencyRow = [[MTHawkeyeNetworkDetailRow alloc] init];
        latencyRow.title = @"Latency";
        latencyRow.detailText = [MTHUISkeletonUtility stringFromRequestDuration:transaction.latency];
        [rows addObject:latencyRow];
    }

#pragma clang diagnostic pop

    MTHawkeyeNetworkDetailSection *generalSection = [[MTHawkeyeNetworkDetailSection alloc] init];
    generalSection.title = @"General";
    generalSection.rows = rows;

    return generalSection;
}

+ (MTHawkeyeNetworkDetailSection *)requestHeadersSectionForTransaction:(MTHNetworkTransaction *)transaction {
    MTHawkeyeNetworkDetailSection *requestHeadersSection = [[MTHawkeyeNetworkDetailSection alloc] init];
    requestHeadersSection.title = @"Request allHTTPHeaderFields";
    MTHawkeyeNetworkDetailRow *row = [[MTHawkeyeNetworkDetailRow alloc] init];
    row.title = @"Request allHTTPHeaderFields";
    row.style = MTHawkeyeNetworkDetailRowWebView;
    NSMutableString *detailText = [[NSMutableString alloc] init];

    [transaction.request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
        [detailText appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
    }];
    row.detailText = detailText;
    if (detailText.length == 0) {
        row.detailText = @"Request allHTTPHeaderFields are nil";
    }
    requestHeadersSection.rows = @[ row ];
    return requestHeadersSection;
}

+ (MTHawkeyeNetworkDetailSection *)postBodySectionForTransaction:(MTHNetworkTransaction *)transaction {
    MTHawkeyeNetworkDetailSection *postBodySection = [[MTHawkeyeNetworkDetailSection alloc] init];
    postBodySection.title = @"Request Body";
    MTHawkeyeNetworkDetailRow *row = [[MTHawkeyeNetworkDetailRow alloc] init];
    if ([transaction.cachedRequestBody length] > 0) {
        if ([transaction.cachedRequestBody length] > kMaxLimitedBody) {
            row.detailText = @"Too long to show, tap to view.";
            row.style = MTHawkeyeNetworkDetailRowDefault;
        } else {
            row.detailText = [MTHUISkeletonUtility prettyJSONStringFromData:[self postBodyDataForTransaction:transaction]];
            row.style = MTHawkeyeNetworkDetailRowWebView;
        }
        row.selectionFuture = ^{
            NSString *contentType = [transaction.request valueForHTTPHeaderField:@"Content-Type"];
            UIViewController *detailViewController = [self detailViewControllerForMIMEType:contentType data:[self postBodyDataForTransaction:transaction]];
            if (detailViewController) {
                detailViewController.title = @"Request Body";
            } else {
                NSString *alertMessage = [NSString stringWithFormat:@"Hawkeye does not have a viewer for request body data with MIME type: %@", [transaction.request valueForHTTPHeaderField:@"Content-Type"]];
                [[[UIAlertView alloc] initWithTitle:@"Can't View Body Data" message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            }
            return detailViewController;
        };
    } else {
        row.detailText = @"Request Body is nil";
    }
    postBodySection.rows = @[ row ];
    return postBodySection;
}

+ (MTHawkeyeNetworkDetailSection *)queryParametersSectionForTransaction:(MTHNetworkTransaction *)transaction {
    NSDictionary *queryDictionary = [MTHUISkeletonUtility dictionaryFromQuery:transaction.request.URL.query];
    MTHawkeyeNetworkDetailSection *querySection = [[MTHawkeyeNetworkDetailSection alloc] init];
    querySection.title = @"Query Parameters";
    querySection.rows = [self networkDetailRowsFromDictionary:queryDictionary];

    return querySection;
}

+ (MTHawkeyeNetworkDetailSection *)responseHeadersSectionForTransaction:(MTHNetworkTransaction *)transaction {
    MTHawkeyeNetworkDetailSection *responseHeadersSection = [[MTHawkeyeNetworkDetailSection alloc] init];
    responseHeadersSection.title = @"Response allHeaderFields";
    if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)transaction.response;
        MTHawkeyeNetworkDetailRow *row = [[MTHawkeyeNetworkDetailRow alloc] init];
        row.title = @"Response allHeaderFields";
        row.style = MTHawkeyeNetworkDetailRowWebView;
        NSMutableString *detailText = [[NSMutableString alloc] init];

        [httpResponse.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj, BOOL *_Nonnull stop) {
            [detailText appendString:[NSString stringWithFormat:@"%@:%@\n", key, obj]];
        }];
        row.detailText = detailText;
        if (detailText.length == 0) {
            row.detailText = @"Response allHeaderFields are nil";
        }
        responseHeadersSection.rows = @[ row ];
    }
    return responseHeadersSection;
}

+ (MTHawkeyeNetworkDetailSection *)responseBodySectionForTransaction:(MTHNetworkTransaction *)transaction {
    MTHawkeyeNetworkDetailSection *responseBodySection = [[MTHawkeyeNetworkDetailSection alloc] init];
    MTHawkeyeNetworkDetailRow *row = [[MTHawkeyeNetworkDetailRow alloc] init];
    responseBodySection.title = @"Response Body";
    if ([transaction.responseBody length] > 0 || transaction.responseContentType == MTHNetworkHTTPContentTypeOther) {
        if (transaction.responseContentType == MTHNetworkHTTPContentTypeOther || [transaction.responseBody length] > kMaxLimitedBody) {
            row.detailText = @"Too long to show, tap to view.";
            row.style = MTHawkeyeNetworkDetailRowDefault;
        } else {
            row.detailText = [MTHUISkeletonUtility prettyJSONStringFromData:transaction.responseBody];
            row.style = MTHawkeyeNetworkDetailRowWebView;
        }
        __weak NSData *weakResponseData = transaction.responseBody;
        row.selectionFuture = ^{
            if (transaction.responseContentType == MTHNetworkHTTPContentTypeOther) {
                __block UIViewController *responseBodyDetailViewController = nil;
                __block NSString *mineType = nil;
                __block NSData *viewControllerData;
                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                NSURLSession *session = [NSURLSession sharedSession];
                NSURLSessionTask *task = [session dataTaskWithRequest:transaction.request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        mineType = response.MIMEType;
                                                        viewControllerData = data;
                                                        dispatch_semaphore_signal(sem);
                                                    }];
                [task resume];
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                responseBodyDetailViewController = [self detailViewControllerForMIMEType:mineType data:viewControllerData];
                return responseBodyDetailViewController;
            } else {
                UIViewController *responseBodyDetailViewController = nil;
                NSData *strongResponseData = weakResponseData;
                if (strongResponseData) {
                    responseBodyDetailViewController = [self detailViewControllerForMIMEType:transaction.response.MIMEType data:strongResponseData];
                    if (!responseBodyDetailViewController) {
                        NSString *alertMessage = [NSString stringWithFormat:@"Hawkeye does not have a viewer for responses with MIME type: %@", transaction.response.MIMEType];
                        [[[UIAlertView alloc] initWithTitle:@"Can't View Response" message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                    }
                    responseBodyDetailViewController.title = @"Response";
                } else {
                    NSString *alertMessage = @"The response has been purged from the cache";
                    [[[UIAlertView alloc] initWithTitle:@"Can't View Response" message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                }
                return responseBodyDetailViewController;
            }
        };
    } else {
        row.detailText = @"Response Body is nil";
    }
    responseBodySection.rows = @[ row ];
    return responseBodySection;
}

+ (NSArray *)networkDetailRowsFromDictionary:(NSDictionary *)dictionary {
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[dictionary count]];
    NSArray *sortedKeys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        NSString *value = dictionary[key];
        MTHawkeyeNetworkDetailRow *row = [[MTHawkeyeNetworkDetailRow alloc] init];
        row.title = key;
        row.detailText = [value description];
        [rows addObject:row];
    }
    return [rows copy];
}

+ (UIViewController *)detailViewControllerForMIMEType:(NSString *)mimeType data:(NSData *)data {
    // FIXME (RKO): Don't rely on UTF8 string encoding
    UIViewController *detailViewController = nil;
    if ([MTHUISkeletonUtility isValidJSONData:data] || [mimeType isEqual:@"application/json"]) {
        NSString *prettyJSON = [MTHUISkeletonUtility prettyJSONStringFromData:data];
        if ([prettyJSON length] > 0) {
            detailViewController = [[MTHawkeyeWebViewController alloc] initWithText:prettyJSON];
        }
    } else if ([mimeType hasPrefix:@"image/"]) {
        UIImage *image = [UIImage imageWithData:data];
        if (image == nil) {
            if ([mimeType containsString:@"webp"]) {
                SEL sdWebPSEL = NSSelectorFromString(@"sd_imageWithWebPData:");
                if ([UIImage respondsToSelector:sdWebPSEL]) {
                    image = [UIImage performSelector:sdWebPSEL withObject:data];
                }
            }
        }
        if (image == nil) {
            Class yyImageCls = NSClassFromString(@"YYImage");
            if (yyImageCls) {
                SEL yyImgSEL = NSSelectorFromString(@"imageWithData:");
                image = [yyImageCls performSelector:yyImgSEL withObject:data];
            }
        }
        detailViewController = [[FLEXImagePreviewViewController alloc] initWithImage:image];
    } else if ([mimeType isEqual:@"application/x-plist"]) {
        id propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
        detailViewController = [[MTHawkeyeWebViewController alloc] initWithText:[propertyList description]];
    }

    // Fall back to trying to show the response as text
    if (!detailViewController) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([text length] > 0) {
            detailViewController = [[MTHawkeyeWebViewController alloc] initWithText:text];
        }
    }
    return detailViewController;
}

+ (NSData *)postBodyDataForTransaction:(MTHNetworkTransaction *)transaction {
    NSData *bodyData = transaction.cachedRequestBody;
    if ([bodyData length] > 0) {
        NSString *contentEncoding = [transaction.request valueForHTTPHeaderField:@"Content-Encoding"];
        if ([contentEncoding rangeOfString:@"deflate" options:NSCaseInsensitiveSearch].length > 0 || [contentEncoding rangeOfString:@"gzip" options:NSCaseInsensitiveSearch].length > 0) {
            bodyData = [MTHUISkeletonUtility inflatedDataFromCompressedData:bodyData];
        }
    }
    return bodyData;
}
@end
