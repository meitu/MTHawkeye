//
//  main.m
//  MTHAllocationsReader
//
//  Created by EuanC on 2018/11/27.
//  Copyright © 2018 meitu.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MTHAHistoryRecordReader.h"
#import "cxxopts.hpp"

using namespace std;
using namespace cxxopts;

ParseResult parse(int argc, char *argv[]) {
    try {
        Options options(argv[0], " - hawkeye allocations report generator options");
        options.positional_help("[optional args]").show_positional_help();

        // clang-format off

        options.allow_unrecognised_options().add_options()
            ("d,directory", "allocations record files directory", value<string>())
            ("m,malloc_threshold", "malloc report threshold in byte", value<int>())
            ("v,vmalloc_threshold", "vmallocate report threshold in byte", value<int>())
            ("s,symbolicate_server_url", "remote symbolicate server url", value<string>(), "empty");

        // clang-format on

        auto result = options.parse(argc, argv);

        if (result.count("help")) {
            cout << options.help({"", "Group"}) << endl;
            exit(0);
        }

        if (result.count("d")) {
            cout << "[Record Directory]: " << result["d"].as<string>() << endl;
        }
        if (result.count("m")) {
            cout << "[Malloc Report Threshold]: " << result["m"].as<int>() << " bytes" << endl;
        } else {
            cout << "[Default Malloc Report Threshold]: " << result["m"].as<int>() << " bytes" << endl;
        }

        if (result.count("v")) {
            cout << "[VMAllocate Report Threshold]: " << result["v"].as<int>() << " bytes" << endl;
        }
        if (result.count("s")) {
            cout << "[Remote Symbolicate URL]: " << result["s"].as<string>() << endl;
        }
        return result;

    } catch (const OptionException &e) {
        cout << "error parsing options: " << e.what() << endl;
        exit(1);
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        ParseResult result = parse(argc, argv);
        string dir = result["d"].as<string>();
        int malloc_threshold = result["m"].as<int>();
        int vmalloc_threshold = result["v"].as<int>();
        auto arguments = result.arguments();

        NSString *dirStr = [NSString stringWithUTF8String:dir.c_str()];
        MTHAHistoryRecordReader *reader = [[MTHAHistoryRecordReader alloc] initWithRecordDir:dirStr];
        [reader generateReportWithMallocThresholdInBytes:malloc_threshold vmThresholdInBytes:vmalloc_threshold];

        // symbolicalize server
        if (result.count("s")) {
            string symbolica_url = result["s"].as<string>();
        }
    }
    return 0;
}
