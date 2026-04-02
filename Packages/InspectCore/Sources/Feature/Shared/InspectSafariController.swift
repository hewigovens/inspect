#if !os(macOS)
    import SafariServices
    import SwiftUI

    struct InspectSafariController: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context _: Context) -> SFSafariViewController {
            let controller = SFSafariViewController(url: url)
            controller.preferredControlTintColor = UIColor(Color.inspectAccent)
            return controller
        }

        func updateUIViewController(_: SFSafariViewController, context _: Context) {}
    }

    extension View {
        func inspectSafariSheet(url: URL?, isPresented: Binding<Bool>) -> some View {
            sheet(isPresented: isPresented) {
                if let url {
                    InspectSafariController(url: url)
                }
            }
        }
    }
#else
    import SwiftUI

    extension View {
        func inspectSafariSheet(url _: URL?, isPresented _: Binding<Bool>) -> some View {
            self
        }
    }
#endif
