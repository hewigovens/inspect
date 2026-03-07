import Darwin
import Foundation

struct TLSFlowObservationFeedStorage {
    let fileURL: URL
    let maximumPendingItems: Int

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func append(_ observation: TLSFlowObservation) throws -> Int {
        try withLockedFile { fileDescriptor in
            var observations = try loadObservations(from: fileDescriptor)
            observations.append(observation)

            if observations.count > maximumPendingItems {
                observations.removeFirst(observations.count - maximumPendingItems)
            }

            try persist(observations, to: fileDescriptor)
            return observations.count
        }
    }

    func drain(maxCount: Int) throws -> (observations: [TLSFlowObservation], remainingCount: Int) {
        try withLockedFile { fileDescriptor in
            var observations = try loadObservations(from: fileDescriptor)
            let count = max(0, min(maxCount, observations.count))
            let drained = Array(observations.prefix(count))
            observations.removeFirst(count)
            try persist(observations, to: fileDescriptor)
            return (drained, observations.count)
        }
    }

    func reset() throws {
        try withLockedFile { fileDescriptor in
            if ftruncate(fileDescriptor, 0) != 0 {
                throw TLSFlowObservationFeedStorageError.systemCallFailed(
                    operation: "truncate observation queue",
                    errno: errno
                )
            }
        }
    }

    func pendingCount() throws -> Int {
        try withLockedFile { fileDescriptor in
            try loadObservations(from: fileDescriptor).count
        }
    }

    private func withLockedFile<Result>(_ body: (Int32) throws -> Result) throws -> Result {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileDescriptor = open(fileURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "open observation queue",
                errno: errno
            )
        }

        defer {
            _ = flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
        }

        guard flock(fileDescriptor, LOCK_EX) == 0 else {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "lock observation queue",
                errno: errno
            )
        }

        return try body(fileDescriptor)
    }

    private func loadObservations(from fileDescriptor: Int32) throws -> [TLSFlowObservation] {
        let data = try readAll(from: fileDescriptor)
        guard data.isEmpty == false else {
            return []
        }

        do {
            return try decoder.decode([TLSFlowObservation].self, from: data)
        } catch {
            throw TLSFlowObservationFeedStorageError.decodeFailed(error)
        }
    }

    private func persist(_ observations: [TLSFlowObservation], to fileDescriptor: Int32) throws {
        let data: Data
        do {
            data = try encoder.encode(observations)
        } catch {
            throw TLSFlowObservationFeedStorageError.encodeFailed(error)
        }

        if ftruncate(fileDescriptor, 0) != 0 {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "truncate observation queue",
                errno: errno
            )
        }
        if lseek(fileDescriptor, 0, SEEK_SET) < 0 {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "seek observation queue",
                errno: errno
            )
        }

        try writeAll(data, to: fileDescriptor)
        if fsync(fileDescriptor) != 0 {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "sync observation queue",
                errno: errno
            )
        }
    }

    private func readAll(from fileDescriptor: Int32) throws -> Data {
        if lseek(fileDescriptor, 0, SEEK_SET) < 0 {
            throw TLSFlowObservationFeedStorageError.systemCallFailed(
                operation: "seek observation queue",
                errno: errno
            )
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let readCount = read(fileDescriptor, &buffer, buffer.count)
            if readCount < 0 {
                throw TLSFlowObservationFeedStorageError.systemCallFailed(
                    operation: "read observation queue",
                    errno: errno
                )
            }
            if readCount == 0 {
                break
            }
            data.append(contentsOf: buffer[..<readCount])
        }
        return data
    }

    private func writeAll(_ data: Data, to fileDescriptor: Int32) throws {
        guard data.isEmpty == false else {
            return
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            var bytesWritten = 0
            while bytesWritten < data.count {
                let writeCount = write(fileDescriptor, baseAddress + bytesWritten, data.count - bytesWritten)
                if writeCount < 0 {
                    throw TLSFlowObservationFeedStorageError.systemCallFailed(
                        operation: "write observation queue",
                        errno: errno
                    )
                }
                bytesWritten += writeCount
            }
        }
    }
}

private enum TLSFlowObservationFeedStorageError: LocalizedError {
    case systemCallFailed(operation: String, errno: Int32)
    case decodeFailed(any Error)
    case encodeFailed(any Error)

    var errorDescription: String? {
        switch self {
        case let .systemCallFailed(operation, errnoValue):
            return "Failed to \(operation): \(String(cString: strerror(errnoValue)))"
        case let .decodeFailed(error):
            return "Failed to decode observation queue: \(error.localizedDescription)"
        case let .encodeFailed(error):
            return "Failed to encode observation queue: \(error.localizedDescription)"
        }
    }
}
