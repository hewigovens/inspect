@testable import InspectCore
import Foundation
import Testing

@Test
func tlsFlowObservationFeedPersistsAndDrainsObservations() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TLSFlowObservationFeedTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("feed.json")
    let feed = TLSFlowObservationFeed(fileURL: fileURL)

    let first = TLSFlowObservation(
        source: .networkExtension,
        transport: .tcp,
        remoteHost: "example.com",
        remotePort: 443,
        serverName: "example.com"
    )
    let second = TLSFlowObservation(
        source: .networkExtension,
        transport: .tcp,
        remoteHost: "api.example.com",
        remotePort: 443,
        serverName: "api.example.com"
    )

    await feed.append(first)
    await feed.append(second)

    #expect(await feed.pendingCount() == 2)

    let drained = await feed.drain(maxCount: 1)
    #expect(drained.count == 1)
    #expect(drained.first?.remoteHost == "example.com")
    #expect(await feed.pendingCount() == 1)

    let remaining = await feed.drain(maxCount: 5)
    #expect(remaining.count == 1)
    #expect(remaining.first?.remoteHost == "api.example.com")
    #expect(await feed.pendingCount() == 0)

    await feed.reset()
    #expect(await feed.pendingCount() == 0)
}
