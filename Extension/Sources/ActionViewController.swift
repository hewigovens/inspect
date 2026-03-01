import InspectFeature
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ActionViewController: UIViewController {
    private var hostingController: UIHostingController<InspectionRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        Task {
            let initialURL = await ExtensionInputLoader.loadURL(from: extensionContext)
            await MainActor.run {
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
    }
}

private enum ExtensionInputLoader {
    static func loadURL(from context: NSExtensionContext?) async -> URL? {
        guard let items = context?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
                    return url
                }
            }
        }

        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let url = await loadURL(from: provider, typeIdentifier: UTType.plainText.identifier) {
                    return url
                }
            }
        }

        return nil
    }

    private static func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                    return
                }

                if let text = item as? String {
                    continuation.resume(returning: URL(string: text))
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
