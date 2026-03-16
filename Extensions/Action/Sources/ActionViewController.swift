import InspectKit
import SwiftUI
import UIKit
import InspectCore

final class ActionViewController: UIViewController {
    private var hostingController: UIHostingController<InspectionRootView>?
    private let logger = InspectRuntimeLogger(
        category: "ActionExtension",
        scope: "iOSActionExtension"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        logger.verbose("iOS action extension viewDidLoad")

        Task {
            let initialURL = await ExtensionInputExtractor.loadURL(from: extensionContext)
            await MainActor.run {
                self.logger.verbose("iOS action extension embedding root view. initialURL=\(initialURL?.absoluteString ?? "nil")")
                embedRootView(initialURL: initialURL)
            }
        }
    }

    private func embedRootView(initialURL: URL?) {
        let rootView = InspectionRootView(
            initialURL: initialURL,
            closeAction: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            presentation: .actionExtension
        )

        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
        logger.verbose("iOS action extension root view embedded")
    }
}
