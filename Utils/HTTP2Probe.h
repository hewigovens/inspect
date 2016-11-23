//
//  HTTP2Probe.h
//  Inspect
//
//  Created by hewig on 11/20/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTTP2Probe : NSObject

+ (void)probeURL:(nonnull NSURL*)url
      completion:(void (^ _Nullable)(BOOL result))completion;

@end
