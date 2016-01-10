//
//  SessionManager.swift
//  Inspect
//
//  Created by hewig on 1/10/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

public typealias fetchCertsHandler = ([SecCertificate]) -> Void

public class SessionManager: NSObject, NSURLSessionTaskDelegate {
    static let sharedManager = SessionManager()
    private var session: NSURLSession?
    private var requestQueue = NSOperationQueue()
    private var callbacks = [NSURL: fetchCertsHandler]()
    
    override init() {
        super.init()
        self.session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: self.requestQueue)
    }
    
    public func fetchCertsForUrl(url: NSURL, completion: fetchCertsHandler) -> Void {
        let task = self.session?.dataTaskWithURL(url)
        guard task == nil else { return completion([]) }
        self.callbacks[url] = completion
        task!.resume()
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        
        let certs = self.certificateDataForTrust(challenge.protectionSpace.serverTrust!)
        if let url = task.originalRequest?.URL {
            if let callback = self.callbacks[url] {
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    callback(certs)
                    self.callbacks.removeValueForKey(url)
                }
            }
        }
        completionHandler(.CancelAuthenticationChallenge, challenge.proposedCredential);
    }

    private func certificateDataForTrust(trust: SecTrust) -> [SecCertificate] {
        var certs: [SecCertificate] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let cert = SecTrustGetCertificateAtIndex(trust, index) {
                certs.append(cert)
            }
        }
        return certs.reverse();
    }
}