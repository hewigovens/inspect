//
//  SessionManager.swift
//  Inspect
//
//  Created by hewig on 1/10/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

public typealias FetchCertsHandler = ([(SecCertificate, SecTrustResultType)]) -> Void

open class SessionManager: NSObject, URLSessionTaskDelegate {
    static let shared = SessionManager()
    fileprivate var session: Foundation.URLSession?
    fileprivate var requestQueue = OperationQueue()
    fileprivate var callbacks = [URL: FetchCertsHandler]()

    override init() {
        super.init()
        self.session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: self.requestQueue)
    }

    open func fetchCertsForUrl(_ url: URL, completion: @escaping FetchCertsHandler) {
        guard let task = self.session?.dataTask(with: url) else {
            return completion([])
        }
        self.callbacks[url] = completion
        task.resume()
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let certs = self.certificateDataForTrust(challenge.protectionSpace.serverTrust!)
        if let url = task.originalRequest?.url {
            if let callback = self.callbacks[url] {
                DispatchQueue.main.async { () -> Void in
                    callback(certs)
                    self.callbacks.removeValue(forKey: url)
                }
            }
        }
        completionHandler(.cancelAuthenticationChallenge, challenge.proposedCredential)
    }

    fileprivate func certificateDataForTrust(_ trust: SecTrust) -> [(SecCertificate, SecTrustResultType)] {
        var certs: [(SecCertificate, SecTrustResultType)] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let cert = SecTrustGetCertificateAtIndex(trust, index) {

                var result = SecTrustResultType.unspecified
                if SecTrustGetTrustResult(trust, &result) == 0 {
                    certs.append((cert, result))
                } else {
                    certs.append((cert, SecTrustResultType.unspecified))
                }
            }
        }
        return certs.reversed()
    }
}
