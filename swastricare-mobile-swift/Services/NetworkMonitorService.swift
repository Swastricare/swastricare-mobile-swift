import Foundation
import Network
import Combine

@MainActor
protocol NetworkMonitorServiceProtocol: AnyObject {
    var isConnected: Bool { get }
    var isSyncing: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

@MainActor
final class NetworkMonitorService: ObservableObject, NetworkMonitorServiceProtocol {
    static let shared = NetworkMonitorService()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isSyncing: Bool = false

    private var wasOffline = false

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.swastricare.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let connected = path.status == .satisfied
                let previouslyOffline = self.wasOffline

                if !connected {
                    self.wasOffline = true
                }

                self.isConnected = connected

                // Show syncing animation when coming back online
                if connected && previouslyOffline {
                    self.wasOffline = false
                    self.isSyncing = true
                    // Auto-dismiss after data has time to sync
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self.isSyncing = false
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Call this when a manual sync completes to dismiss the indicator early
    func syncCompleted() {
        isSyncing = false
    }

    deinit {
        monitor.cancel()
    }
}
