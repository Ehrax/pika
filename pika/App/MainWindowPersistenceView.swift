#if os(macOS)
import AppKit
import SwiftUI

struct MainWindowPersistenceView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []

        deinit {
            removeObservers()
        }

        func attach(to nextWindow: NSWindow?) {
            guard let nextWindow, nextWindow !== window else { return }

            removeObservers()
            window = nextWindow

            let autosaveName = MainWindowLayout.frameAutosaveName
            let restoredFrame = restoreStoredFrame(into: nextWindow) || nextWindow.setFrameUsingName(autosaveName)
            if !restoredFrame {
                applyDefaultFrame(to: nextWindow)
            }
            nextWindow.setFrameAutosaveName(autosaveName)
            recordFrame(for: nextWindow, event: restoredFrame ? "restored" : "attached")

            observe(NSWindow.didMoveNotification, for: nextWindow, event: "moved")
            observe(NSWindow.didEndLiveResizeNotification, for: nextWindow, event: "resized")
        }

        private func observe(
            _ notificationName: NSNotification.Name,
            for window: NSWindow,
            event: String
        ) {
            let observer = NotificationCenter.default.addObserver(
                forName: notificationName,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let window else { return }
                self?.recordFrame(for: window, event: event)
            }

            observers.append(observer)
        }

        private func recordFrame(for window: NSWindow, event: String) {
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: MainWindowLayout.frameStorageKey)
            AppTelemetry.mainWindowFrameObserved(frame: window.frame, event: event)
        }

        private func restoreStoredFrame(into window: NSWindow) -> Bool {
            guard let storedFrame = UserDefaults.standard.string(forKey: MainWindowLayout.frameStorageKey) else {
                return false
            }

            let frame = NSRectFromString(storedFrame)
            guard frame.width > 0, frame.height > 0 else { return false }

            window.setFrame(frame, display: true)
            return true
        }

        private func applyDefaultFrame(to window: NSWindow) {
            let currentFrame = window.frame
            let defaultSize = PikaApp.defaultLaunchWindowSize
            let frame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y,
                width: defaultSize.width,
                height: defaultSize.height
            )
            window.setFrame(frame, display: true)
        }

        private func removeObservers() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }
    }
}
#endif
