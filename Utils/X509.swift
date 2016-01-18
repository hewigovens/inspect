//
//  X509.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

public struct X509Certificate {

    public var subjectName = ""
    public var issuerName = ""
    
    public var md5 = ""
    public var sha1 = ""
    public var version = 1
    public var serialNumber = ""
    
    public var signature = ""
    public var signatureAlgorithm = ""
    
    public var pubKey = ""
    public var pubKeySize = -1
    public var pubKeyAlgorithm = ""
    public var pubKeyECCurveName = ""
    
    public var notValidBefore = ""
    public var notValidAfter = ""
    public var isCA = false
    
    public var subjectAltNames: [String] = []
    public var extensions: [(String, AnyObject)] = []
    
    private var once = dispatch_once_t()
    
    init(certificate: SecCertificate) {
        
        dispatch_once(&once) { () -> Void in
            OPENSSL_add_all_algorithms_noconf()
            OpenSSL_add_all_digests()
            OpenSSL_add_all_ciphers()
        }
        
        let data = SecCertificateCopyData(certificate) as NSData
        var bytes = UnsafePointer<UInt8>(data.bytes)
        let cert = d2i_X509(nil, &bytes, data.length)

        self.subjectName = X509Helper.getSubject(cert)
        self.issuerName = X509Helper.getIssuer(cert)
        self.version = ASN1_INTEGER_get(cert.memory.cert_info.memory.version) + 1
        let serial = ASN1_INTEGER_to_BN(X509_get_serialNumber(cert), nil)
        self.serialNumber = (String.fromCString(BN_bn2hex(serial))?.lowercaseString)!
        
        let cert_nid = OBJ_obj2nid(cert.memory.sig_alg.memory.algorithm)
        if let s = String.fromCString(OBJ_nid2ln(cert_nid)) {
            self.signatureAlgorithm = s
        }
        
        self.signature = X509Helper.signatureOfCert(cert).lowercaseString
        let pkey = X509_get_pubkey(cert)
        let pkey_nid = OBJ_obj2nid(cert.memory.cert_info.memory.key.memory.algor.memory.algorithm)
        if let s = String.fromCString(OBJ_nid2ln(pkey_nid)) {
            self.pubKeyAlgorithm = s
        }
        self.pubKey = X509Helper.hexPubKey(pkey)
        self.pubKeySize = X509Helper.sizeOfPubKey(pkey)
        self.pubKeyECCurveName = X509Helper.ECCurveNameOfPubKey(pkey)
        
        self.subjectAltNames = X509Helper.subjectAltNamesOfCert(cert)

        self.notValidBefore = X509Helper.getNotBefore(cert)
        self.notValidAfter = X509Helper.getNotAfter(cert)
        self.isCA = (X509_check_ca(cert) >= 1)
        
        self.md5 = X509Helper.x509Digest(cert, method: "md5")
        self.sha1 = X509Helper.x509Digest(cert, method: "sha1")
        
        let exts = X509Helper.extensionsOfCert(cert)
        for dict in exts {
            self.extensions.append((dict["key"] as! String, dict["value"]!))
        }
        
        defer {
            EVP_PKEY_free(pkey)
            X509_free(cert)
        }
    }
}

extension X509Certificate: CustomStringConvertible {
    
    public var description: String {
        var description = "X509Certificate: {\n"
        description += "\t subject = \(self.subjectName)\n"
        description += "\t issuer = \(self.issuerName)\n"
        description += "\t version = \(self.version)\n"
        description += "\t serial number = \(self.serialNumber)\n"
        description += "\t signature algorithm = \(self.signatureAlgorithm)\n"
        description += "\t not valid before = \(self.notValidBefore)\n"
        description += "\t not valid after = \(self.notValidAfter)\n"
        description += "\t is CA = \(self.isCA)\n"
        description += "\t pubkey is = \(self.pubKey)\n"
        description += "\t md5 fingerprint = \(self.md5)\n"
        description += "\t sha1 fingerprint = \(self.sha1)\n"
        description += "}\n"
        return description
    }
}

extension X509Helper {
    
    static func getSubject(cert: UnsafeMutablePointer<x509_st>) -> String {
        let subject = X509_get_subject_name(cert)
        if let s = String.fromCString(X509_NAME_oneline(subject, nil, 0)) {
            return s
        }
        return ""
    }
    
    static func getIssuer(cert: UnsafeMutablePointer<x509_st>) -> String {
        let issuer = X509_get_issuer_name(cert)
        if let s = String.fromCString(X509_NAME_oneline(issuer, nil, 0)) {
            return s
        }
        return ""
    }
    
    static func convertASN1TimeToString(time: UnsafePointer<ASN1_TIME>) -> String {
        let bio = BIO_new(BIO_s_mem())
        defer {
            BIO_free(bio)
        }
        if ASN1_TIME_print(bio, time) > 0 {
            var buffer = UnsafeMutablePointer<Int8>.alloc(128)
            defer {
                buffer.destroy()
                buffer.dealloc(128)
                buffer = nil
            }
            if BIO_gets(bio, buffer, 128) > 0 {
                
                let string = String.fromCString(buffer)!
                let inFormatter = NSDateFormatter()
                let outFormatter = NSDateFormatter()
                inFormatter.dateFormat = "MMM dd HH:mm:ss yyyy zzz"
                outFormatter.dateFormat = "MM/dd/yy, hh:mm:ss a"
                let date = inFormatter.dateFromString(string)
                return outFormatter.stringFromDate(date!)
            }
        }
        return ""
    }
    
    static func x509Digest(cert: UnsafePointer<x509_st>, method: String) -> String {
        var buffer = UnsafeMutablePointer<UInt8>.alloc(64)
        var len_ptr = UnsafeMutablePointer<UInt32>.alloc(1)
        defer {
            buffer.destroy()
            buffer.dealloc(64)
            buffer = nil
            
            len_ptr.destroy()
            len_ptr.dealloc(1)
            len_ptr = nil
        }
        
        let md = EVP_get_digestbyname(method)
        var string = ""
        if X509_digest(cert, md, buffer, len_ptr) > 0{
            let len = Int(len_ptr.memory)
            if len > 0 {
                let p = UnsafePointer<UInt8>(buffer)
                for char in UnsafeBufferPointer(start: p, count: len) {
                        string += String(format: "%02x", char)
                }
            }
        }
        return string
    }

    static func x509PubKeyDigest(cert: UnsafePointer<x509_st>) -> String {
        
        let pkey_nid = OBJ_obj2nid(cert.memory.sig_alg.memory.algorithm)
        let method = EVP_get_digestbyname(OBJ_nid2ln(pkey_nid))
        var buffer = UnsafeMutablePointer<UInt8>.alloc(256)
        var len_ptr = UnsafeMutablePointer<UInt32>.alloc(1)
        defer {
            buffer.destroy()
            buffer.dealloc(256)
            buffer = nil
            
            len_ptr.destroy()
            len_ptr.dealloc(1)
            len_ptr = nil
        }
        if X509_pubkey_digest(cert, method, buffer, len_ptr) > 0 {
            let p = UnsafePointer<UInt8>(buffer)
            let len = Int(len_ptr.memory)
            var string = ""
            for char in UnsafeBufferPointer(start: p, count: len) {
                string += String(format: "%02x", char)
            }
            return string
        }
        
        return ""
    }
    
    static func getNotBefore(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notBefore
        return self.convertASN1TimeToString(time)
    }
    
    static func getNotAfter(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notAfter
        return self.convertASN1TimeToString(time)
    }
    
    static func signatureOfCert(cert: UnsafePointer<x509_st>) -> String {
        let sig = cert.memory.signature
        let len = Int(sig.memory.length)
        let p = UnsafePointer<UInt8>(sig.memory.data)
        var string = ""
        for char in UnsafeBufferPointer(start: p, count: len) {
            string += String(format: "%02x", char)
        }
        return string
    }
    
    static func subjectAltNames(cert: UnsafePointer<x509_st>) -> [String] {
        return []
    }
}