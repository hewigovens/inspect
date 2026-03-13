import InspectCore
import InspectFeature
import SwiftUI

@main
struct InspectApp: App {
    var body: some Scene {
        WindowGroup {
            InspectAppRootView()
                .onOpenURL { url in
                    guard let deepLink = InspectDeepLink(url: url) else {
                        return
                    }

                    switch deepLink {
                    case let .certificateDetail(token):
                        guard let report = InspectionSharedReportStore.consume(token: token) else {
                            return
                        }

                        InspectionExternalInputCenter.submitReport(report, opensCertificateDetail: true)
                    }
                }
        }
    }
}
