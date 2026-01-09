import AppKit
import Combine

final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let store = UrgeStore.shared
    private let autoFade = AutoFadeReconciler(store: .shared)

    private var cancellables = Set<AnyCancellable>()

    private func coloredCircle(_ color: NSColor) -> NSImage? {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        path.fill()
        image.unlockFocus()
        return image
    }

    override init() {
        super.init()
        constructMenu()
        autoFade.start()

        store.$activeEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.constructMenu()
            }
            .store(in: &cancellables)
    }

    private func constructMenu() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "circle.hexagonpath.fill", accessibilityDescription: "Dopamine Trainer")

        let menu = NSMenu()

        let startUrgeItem = NSMenuItem(title: "Dopamine Craving", action: #selector(startUrgeAction), keyEquivalent: "")
        startUrgeItem.target = self
        startUrgeItem.image = coloredCircle(NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.7, alpha: 1.0))
        menu.addItem(startUrgeItem)

        let hasActive = store.mostRecentActive() != nil

        let beatItItem = NSMenuItem(title: "Beat it!", action: #selector(beatItAction), keyEquivalent: "")
        beatItItem.target = self
        beatItItem.isEnabled = hasActive
        beatItItem.image = coloredCircle(NSColor(calibratedRed: 0.76, green: 0.94, blue: 0.78, alpha: 1.0))
        menu.addItem(beatItItem)

        let scratchedItem = NSMenuItem(title: "Scratched the itch", action: #selector(scratchedItchAction), keyEquivalent: "")
        scratchedItem.target = self
        scratchedItem.isEnabled = hasActive
        scratchedItem.image = coloredCircle(NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.8, alpha: 1.0))
        menu.addItem(scratchedItem)

        statusItem.menu = menu
    }

    @objc private func startUrgeAction() {
        store.createActive()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func beatItAction() {
        if let entry = store.mostRecentActive() {
            store.resolve(entryId: entry.id, status: .beatIt)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func scratchedItchAction() {
        if let entry = store.mostRecentActive() {
            store.resolve(entryId: entry.id, status: .satisfied)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
