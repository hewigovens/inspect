//
//  PurchaseHelper.swift
//  Inspect
//
//  Created by hewig on 3/8/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation
import StoreKit

class PurchaseHelper: NSObject,
                      SKProductsRequestDelegate,
                      SKPaymentTransactionObserver {

    static let sharedHelper = PurchaseHelper()
    static let donationId = "donation_1"
    var products = Dictionary<String, [SKProduct]>()

    static func makeDonation() {

        let request = SKProductsRequest(productIdentifiers: Set(arrayLiteral: PurchaseHelper.donationId))
        request.delegate = PurchaseHelper.sharedHelper
        request.start()
    }

    internal func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {

    }

    internal func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {

    }
}
