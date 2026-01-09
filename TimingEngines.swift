import Foundation
import Combine

final class UrgeTimerEngine: ObservableObject {
    static let shared = UrgeTimerEngine()

    @Published var currentDate: Date = Date()

    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.currentDate = Date()
        }
    }

    deinit {
        timer?.invalidate()
    }
}

final class AutoFadeReconciler {
    private var timer: Timer?
    private let store: UrgeStore

    init(store: UrgeStore = .shared) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reconcile()
        }
        reconcile()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func reconcile() {
        let now = Date()
        for entry in store.activeEntries {
            if now.timeIntervalSince(entry.createdAt) >= 24 * 3600 {
                store.resolve(entryId: entry.id, status: .faded, resolvedAt: now)
            }
        }
    }
}
