//
//  Dopamine_TrainerApp.swift
//  Dopamine Trainer
//
//  Auto-generated from spec by assistant
//

import SwiftUI

@main
struct Dopamine_TrainerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ActiveTimersPage()
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = MenuBarController.shared
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

