//
//  ObjC.m
//  Inspect
//
//  Created by Tao Xu on 9/22/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

#import "catchNSException.h"

@implementation ObjC

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}

@end
