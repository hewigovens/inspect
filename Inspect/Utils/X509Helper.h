//
//  X509Helper.h
//  Inspect
//
//  Created by hewig on 1/9/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <openssl/x509.h>
#import <openssl/ossl_typ.h>

/*
 * Helper Class for X509.swift
 * Swift has only partial support of C union types. When importing C aggregates containing unions, Swift cannot access unsupported 
 * fields.However, C and Objective-C APIs that have arguments of those types or return values of those types can be used in Swift.
 */
@interface X509Helper : NSObject

+ (nonnull NSString *)hexPubKey:(nonnull EVP_PKEY *)pubKey;
+ (nonnull NSString *)typeStringOfPubKey:(nonnull EVP_PKEY *)pubKey;
+ (nonnull NSString *)ECCurveNameOfPubKey:(nonnull EVP_PKEY *)pubKey;
+ (size_t)sizeOfPubKey:(nonnull EVP_PKEY *)pkey;
+ (nonnull NSArray<NSString *> *)subjectAltNamesOfCert:(nonnull X509*)cert;

@end
