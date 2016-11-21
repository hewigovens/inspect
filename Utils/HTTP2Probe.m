//
//  HTTP2Probe.m
//  Inspect
//
//  Created by hewig on 11/20/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#import "HTTP2Probe.h"

#import "nghttp2client.h"

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/conf.h>

@implementation HTTP2Probe

+(void)initialize
{
    SSL_load_error_strings();
    SSL_library_init();
}

+ (void)probeURL:(nonnull NSURL*)url
      completion:(void (^ _Nullable)(BOOL result))completion
{
    const char *url_str = url.absoluteString.UTF8String;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int result = probe(url_str);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion ? completion(result > 0) : nil;
        });
    });
}

@end
