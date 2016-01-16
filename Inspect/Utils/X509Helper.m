//
//  X509Helper.m
//  Inspect
//
//  Created by hewig on 1/9/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#import "X509Helper.h"
#import <openssl/evp.h>
#import <openssl/ec.h>
#import <openssl/ec_lcl.h>
#import <openssl/bn.h>

@implementation X509Helper

+ (NSString *)hexPubKey:(EVP_PKEY *)pubKey nid:(int32_t)nid
{
    if (nid == NID_rsaEncryption) {
        RSA *rsa_key = pubKey->pkey.rsa;
        // exponent
        //char *rsa_e_dec = BN_bn2dec(rsa_key->e);
        char *rsa_n_hex = BN_bn2hex(rsa_key->n);
        return [[NSString stringWithUTF8String:rsa_n_hex] lowercaseString];
    } else if (nid == NID_X9_62_id_ecPublicKey) {
        EC_KEY* key = pubKey->pkey.ec;
        const EC_POINT *ec_pubkey = EC_KEY_get0_public_key(key);
        char *hex = EC_POINT_point2hex(key->group, ec_pubkey, POINT_CONVERSION_UNCOMPRESSED, NULL);
        return [[NSString stringWithUTF8String:hex] lowercaseString];
    }
    return @"";
}

//+ (nonnull NSString *)fingerprint:(nonnull X509 *)cert method:(nonnull NSString*)method
//{
//    unsigned char buffer[EVP_MAX_MD_SIZE];
//    unsigned int len = 0;
//    
//    const EVP_MD *md = EVP_get_digestbyname([method UTF8String]);
//    if (md == NULL) {
//        if ([method isEqualToString:@"sha1"]) {
//            md = EVP_sha1();
//        } else if ([method isEqualToString:@"md5"]) {
//            md = EVP_md5();
//        }
//    }
//    
//    if (md == NULL) {
//        return @"";
//    }
//    
//    X509_digest(cert, md, buffer, &len);
//    if (len > 0) {
//        NSMutableString *string = [NSMutableString new];
//        for(size_t i=0; i < len; i++) {
//            [string appendFormat:@"%02x", buffer[i]];
//        }
//        return [NSString stringWithString:string];
//    } else {
//        return @"";
//    }
//}

@end
