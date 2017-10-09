//
//  ObjC.h
//  Inspect
//
//  Created by Tao Xu on 9/22/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjC : NSObject

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;

@end
