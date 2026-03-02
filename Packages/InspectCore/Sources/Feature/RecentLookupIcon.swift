import Foundation
import SwiftUI
import UIKit
private typealias PlatformImage = UIImage

struct RecentLookupIcon: View {
    let host: String?
    @State private var faviconImage: PlatformImage?

    var body: some View {
        Group {
            if let faviconImage {
                Image(platformImage: faviconImage)
                    .resizable()
                    .scaledToFit()
                    .padding(7)
                    .frame(width: 38, height: 38)
                    .background(Color.inspectChromeMutedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                fallback
            }
        }
        .task(id: faviconURL) {
            await loadFavicon()
        }
    }

    private var faviconURL: URL? {
        guard let host, host.isEmpty == false else {
            return nil
        }

        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.blue.opacity(0.14))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: "globe")
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.blue)
            }
    }

    @MainActor
    private func loadFavicon() async {
        guard let faviconURL else {
            faviconImage = nil
            return
        }

        guard let imageData = await FaviconCache.data(for: faviconURL),
              let image = PlatformImage(data: imageData)
        else {
            faviconImage = nil
            return
        }

        faviconImage = image
    }
}

@MainActor
private enum FaviconCache {
    private static let memoryCache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.countLimit = 256
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private static let responseCache = URLCache(
        memoryCapacity: 32 * 1024 * 1024,
        diskCapacity: 256 * 1024 * 1024,
        diskPath: "InspectFaviconCache"
    )

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = responseCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func data(for url: URL) async -> Data? {
        let cacheKey = url as NSURL
        if let cachedData = memoryCache.object(forKey: cacheKey) {
            return cachedData as Data
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        if let cachedResponse = responseCache.cachedResponse(for: request),
           cachedResponse.data.isEmpty == false
        {
            memoryCache.setObject(cachedResponse.data as NSData, forKey: cacheKey, cost: cachedResponse.data.count)
            return cachedResponse.data
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.isEmpty == false
            else {
                return nil
            }

            responseCache.storeCachedResponse(
                CachedURLResponse(response: response, data: data),
                for: request
            )
            memoryCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
            return data
        } catch {
            return nil
        }
    }
}

private extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
