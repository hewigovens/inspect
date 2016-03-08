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
    var products = [SKProduct]()

    static func makeDonation() {
        let request = SKProductsRequest(productIdentifiers: Set([PurchaseHelper.donationId]))
        request.delegate = PurchaseHelper.sharedHelper
        request.start()
        SKPaymentQueue.defaultQueue().addTransactionObserver(PurchaseHelper.sharedHelper)
    }

    internal func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        for product in response.products {
            self.products.append(product)
        }
        if self.products.count > 0 {
            let payment = SKPayment(product: self.products[0])
            SKPaymentQueue.defaultQueue().addPayment(payment)
        }
    }

    internal func request(request: SKRequest, didFailWithError error: NSError) {
        print(error)
    }

    internal func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case SKPaymentTransactionState.Purchased:
                print("Transaction completed successfully.")
                SKPaymentQueue.defaultQueue().finishTransaction(transaction)
            case SKPaymentTransactionState.Failed:
                print("Transaction Failed")
                SKPaymentQueue.defaultQueue().finishTransaction(transaction)
            default:
                print(transaction.transactionState.rawValue)
            }
        }
    }
}
