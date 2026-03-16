import Foundation
import StoreKit

#if canImport(UIKit)
import UIKit
#endif

public enum InspectReviewRequester {
    @MainActor
    public static func requestReview() {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        #elseif os(macOS)
        SKStoreReviewController.requestReview()
        #endif
    }
}
