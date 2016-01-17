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
#import <openssl/x509v3.h>

@implementation X509Helper

+ (NSString *)hexPubKey:(EVP_PKEY *)pubKey
{
    int key_type = EVP_PKEY_type(pubKey->type);
    if (key_type == EVP_PKEY_RSA) {
        RSA *rsa_key = pubKey->pkey.rsa;
        // exponent
        //char *rsa_e_dec = BN_bn2dec(rsa_key->e);
        char *rsa_n_hex = BN_bn2hex(rsa_key->n);
        return [[NSString stringWithUTF8String:rsa_n_hex] lowercaseString];
    } else if (key_type == EVP_PKEY_EC) {
        EC_KEY* key = pubKey->pkey.ec;
        const EC_POINT *ec_pubkey = EC_KEY_get0_public_key(key);
        char *hex = EC_POINT_point2hex(key->group, ec_pubkey, POINT_CONVERSION_UNCOMPRESSED, NULL);
        return [[NSString stringWithUTF8String:hex] lowercaseString];
    }
    
//    X509_signature_print
    return @"";
}

+ (nonnull NSString *)typeStringOfPubKey:(nonnull EVP_PKEY *)pubKey
{
    int key_type = EVP_PKEY_type(pubKey->type);
    if (key_type == EVP_PKEY_RSA) {
        return @"rsa";
    } else if (key_type == EVP_PKEY_DSA) {
        return @"dsa";
    } else if (key_type==EVP_PKEY_DH) {
        return @"dh";
    } else if (key_type==EVP_PKEY_EC) {
        return @"ecc";
    } else {
        return @"";
    }
}

+ (nonnull NSString *)ECCurveNameOfPubKey:(nonnull EVP_PKEY *)pubKey
{
    int key_type = EVP_PKEY_type(pubKey->type);
    if (key_type == EVP_PKEY_EC) {
        const EC_GROUP *group = EC_KEY_get0_group(pubKey->pkey.ec);
        int name = (group != NULL) ? EC_GROUP_get_curve_name(group) : 0;
        return name ? [NSString stringWithUTF8String:OBJ_nid2sn(name)] : @"";
    }
    return @"";
}

+ (size_t)sizeOfPubKey:(nonnull EVP_PKEY *)pkey
{
    int key_type = EVP_PKEY_type(pkey->type);
    int keysize = -1;
    //or in bytes, RSA_size() DSA_size(), DH_size(), ECDSA_size();
    keysize = key_type == EVP_PKEY_RSA && pkey->pkey.rsa->n ? BN_num_bits(pkey->pkey.rsa->n) : keysize;
    keysize = key_type == EVP_PKEY_DSA && pkey->pkey.dsa->p ? BN_num_bits(pkey->pkey.dsa->p) : keysize;
    keysize = key_type == EVP_PKEY_DH  && pkey->pkey.dh->p  ? BN_num_bits(pkey->pkey.dh->p) : keysize;
    keysize = key_type == EVP_PKEY_EC  ? EC_GROUP_get_degree(EC_KEY_get0_group(pkey->pkey.ec)) : keysize;
    return keysize;
}

+ (nonnull NSArray<NSString *> *)subjectAltNamesOfCert:(nonnull X509*)cert
{
    NSMutableArray *list = [NSMutableArray new];
    GENERAL_NAMES* subjectAltNames = (GENERAL_NAMES*)X509_get_ext_d2i(cert, NID_subject_alt_name, NULL, NULL);
    for (int i = 0; i < sk_GENERAL_NAME_num(subjectAltNames); i++)
    {
        GENERAL_NAME* gen = sk_GENERAL_NAME_value(subjectAltNames, i);
        if (gen->type == GEN_URI || gen->type == GEN_DNS || gen->type == GEN_EMAIL)
        {
            ASN1_IA5STRING *asn1_str = gen->d.uniformResourceIdentifier;
            NSString *san = [NSString stringWithUTF8String:(char*)ASN1_STRING_data(asn1_str)/*ASN1_STRING_length(asn1_str)*/];
            [list addObject:san];
        }
        else if (gen->type == GEN_IPADD)
        {
            unsigned char *p = gen->d.ip->data;
            if(gen->d.ip->length == 4)
            {
                NSString *string = [NSString stringWithFormat:@"%d.%d.%d.%d", p[0], p[1], p[2], p[3]];
                [list addObject:string];
            }
            else //if(gen->d.ip->length == 16) //ipv6?
            {
                //std::cerr << "Not implemented: parse sans ("<< __FILE__ << ":" << __LINE__ << ")" << endl;
            }
        }
        else
        {
            //std::cerr << "Not implemented: parse sans ("<< __FILE__ << ":" << __LINE__ << ")" << endl;
        }
    }
    return list;
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
