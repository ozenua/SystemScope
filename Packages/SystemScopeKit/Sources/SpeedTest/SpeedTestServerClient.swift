import Foundation

public struct SpeedTestServerConfig: Decodable, Sendable, Equatable {
    public var serverRegion: String?

    public init(serverRegion: String? = nil) {
        self.serverRegion = serverRegion
    }
}

public struct UploadConfirmation: Sendable, Equatable {
    /// Bytes the server reports it received. The upload figure uses only this.
    public var bytesReceived: Int

    public init(bytesReceived: Int) {
        self.bytesReceived = bytesReceived
    }
}

/// The four test-server endpoints. One client talks to one server.
///
///     GET  /speed/config             -> {"serverRegion": "eu-west"}
///     GET  /speed/ping               -> empty body, Cache-Control: no-store
///     GET  /speed/download?bytes=N   -> N bytes, exact Content-Length, uncompressed
///     POST /speed/upload             -> {"success": true, "bytesReceived": N, ...}
public protocol SpeedTestServerClient: Sendable {
    var host: String { get }
    func fetchConfig() async throws -> SpeedTestServerConfig
    /// One round trip in milliseconds.
    func ping() async throws -> Double
    /// Returns the bytes actually received; `onBytes` fires as they arrive.
    func download(bytes: Int, onBytes: @escaping @Sendable (Int) -> Void) async throws -> Int
    /// `onBytesSent` reports bytes handed to the network stack, for live display only.
    func upload(bytes: Int, onBytesSent: @escaping @Sendable (Int) -> Void) async throws -> UploadConfirmation
}

public struct HTTPSpeedTestClient: SpeedTestServerClient {
    private let baseURL: URL
    private let transport: SpeedTestTransport

    public init(baseURL: URL, transport: SpeedTestTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public var host: String { baseURL.host() ?? baseURL.absoluteString }

    private func request(_ path: String, query: [URLQueryItem] = [], method: String = "GET") -> URLRequest {
        // A unique token per request so nothing between us and the server can cache it.
        let items = query + [URLQueryItem(name: "t", value: UUID().uuidString)]
        var request = URLRequest(url: baseURL.appending(path: path).appending(queryItems: items))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // Compression would make payloads smaller than the bytes we count.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        return request
    }

    public func fetchConfig() async throws -> SpeedTestServerConfig {
        let outcome = try await transport.perform(request("speed/config"), collectBody: true)
        guard outcome.statusCode == 200,
              let config = try? JSONDecoder().decode(SpeedTestServerConfig.self, from: outcome.body) else {
            throw SpeedTestError.serverUnreachable
        }
        return config
    }

    public func ping() async throws -> Double {
        let outcome = try await transport.perform(request("speed/ping"))
        guard (200..<300).contains(outcome.statusCode) else { throw SpeedTestError.serverUnreachable }
        return outcome.roundTripSeconds * 1000
    }

    public func download(bytes: Int, onBytes: @escaping @Sendable (Int) -> Void) async throws -> Int {
        let counter = Counter()
        let outcome = try await transport.perform(
            request("speed/download", query: [URLQueryItem(name: "bytes", value: String(bytes))]),
            onBytesReceived: { count in
                counter.add(count)
                onBytes(count)
            }
        )
        guard outcome.statusCode == 200 else { throw SpeedTestError.serverUnreachable }
        return counter.value
    }

    public func upload(bytes: Int, onBytesSent: @escaping @Sendable (Int) -> Void) async throws -> UploadConfirmation {
        struct Response: Decodable {
            let success: Bool
            let bytesReceived: Int
        }
        var upload = request("speed/upload", method: "POST")
        upload.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let outcome = try await transport.perform(
            upload,
            uploadBody: Self.randomPayload(bytes),
            collectBody: true,
            onBytesSent: onBytesSent
        )
        guard outcome.statusCode == 200,
              let response = try? JSONDecoder().decode(Response.self, from: outcome.body),
              response.success, response.bytesReceived > 0 else {
            throw SpeedTestError.invalidMeasurement
        }
        return UploadConfirmation(bytesReceived: response.bytesReceived)
    }

    /// Random bytes so compression anywhere on the path cannot shrink the payload.
    /// Never stored: it exists only for the duration of the request.
    static func randomPayload(_ count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            if let base = buffer.baseAddress { arc4random_buf(base, count) }
        }
        return data
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func add(_ amount: Int) { lock.withLock { count += amount } }
    var value: Int { lock.withLock { count } }
}

/// A dedicated URLSession for test traffic: no cache, no cookies, short timeouts, and
/// a delegate that reports bytes as they move.
public final class SpeedTestTransport: Sendable {
    struct Outcome: Sendable {
        var statusCode: Int
        var body: Data
        /// Request sent to first response byte, from URLSessionTaskMetrics where
        /// available; this leaves out connection setup on a reused connection.
        var roundTripSeconds: Double
    }

    private let session: URLSession
    private let delegate: TransferDelegate

    public init(configuration: URLSessionConfiguration = SpeedTestTransport.defaultConfiguration) {
        delegate = TransferDelegate()
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    public static var defaultConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 8
        return configuration
    }

    /// Cancels anything in flight. Call when the owning coordinator goes away.
    public func invalidate() {
        session.invalidateAndCancel()
    }

    func perform(
        _ request: URLRequest,
        uploadBody: Data? = nil,
        collectBody: Bool = false,
        onBytesReceived: (@Sendable (Int) -> Void)? = nil,
        onBytesSent: (@Sendable (Int) -> Void)? = nil
    ) async throws -> Outcome {
        let task = uploadBody.map { session.uploadTask(with: request, from: $0) } ?? session.dataTask(with: request)
        let started = ProcessInfo.processInfo.systemUptime
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.register(task.taskIdentifier, TransferDelegate.Handler(
                    collectBody: collectBody,
                    onBytesReceived: onBytesReceived,
                    onBytesSent: onBytesSent,
                    started: started,
                    continuation: continuation
                ))
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }
}

private final class TransferDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    struct Handler {
        var collectBody: Bool
        var onBytesReceived: (@Sendable (Int) -> Void)?
        var onBytesSent: (@Sendable (Int) -> Void)?
        var started: TimeInterval
        var continuation: CheckedContinuation<SpeedTestTransport.Outcome, Error>
        var body = Data()
        var measuredRoundTrip: Double?
    }

    private let lock = NSLock()
    private var handlers: [Int: Handler] = [:]

    func register(_ identifier: Int, _ handler: Handler) {
        lock.withLock { handlers[identifier] = handler }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let callback: (@Sendable (Int) -> Void)? = lock.withLock {
            if handlers[dataTask.taskIdentifier]?.collectBody == true {
                handlers[dataTask.taskIdentifier]?.body.append(data)
            }
            return handlers[dataTask.taskIdentifier]?.onBytesReceived
        }
        callback?(data.count)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        let callback = lock.withLock { handlers[task.taskIdentifier]?.onBytesSent }
        callback?(Int(bytesSent))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transaction = metrics.transactionMetrics.last,
              let sent = transaction.requestStartDate,
              let answered = transaction.responseStartDate, answered > sent else { return }
        lock.withLock { handlers[task.taskIdentifier]?.measuredRoundTrip = answered.timeIntervalSince(sent) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let handler = lock.withLock({ handlers.removeValue(forKey: task.taskIdentifier) }) else { return }
        if let error {
            handler.continuation.resume(throwing: error)
            return
        }
        handler.continuation.resume(returning: SpeedTestTransport.Outcome(
            statusCode: (task.response as? HTTPURLResponse)?.statusCode ?? 0,
            body: handler.body,
            roundTripSeconds: handler.measuredRoundTrip ?? (ProcessInfo.processInfo.systemUptime - handler.started)
        ))
    }
}
