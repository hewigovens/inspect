import Foundation
import StoreKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public enum InspectReviewRequester {
    @MainActor
    public static func requestReview() {
        #if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
            else {
                return
            }

            AppStore.requestReview(in: scene)
        #elseif os(macOS)
            guard let controller = NSApp.keyWindow?.contentViewController
                ?? NSApp.mainWindow?.contentViewController
            else {
                return
            }

            AppStore.requestReview(in: controller)
        #endif
    }
}
