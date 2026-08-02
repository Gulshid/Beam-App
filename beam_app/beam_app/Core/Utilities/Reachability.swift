import Foundation
import Network

/// Thin wrapper around `NWPathMonitor`. ViewModels observe `isOnline` to know when to
/// retry queued sends, instead of polling or waiting on a Firestore call to time out.
@MainActor
final class Reachability: ObservableObject {
    static let shared = Reachability()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "beam.reachability")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}
