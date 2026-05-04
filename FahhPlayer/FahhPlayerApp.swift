//
//  FahhPlayerApp.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  func applicationWillTerminate(_ notification: Notification) {
    NSAppleEventManager.shared().removeEventHandler(
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  @objc private func handleGetURLEvent(
    _ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor
  ) {
    guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
      let url = URL(string: urlString)
    else {
      return
    }

    TerminalCommandURLRouter.handle(url)
  }
}

enum TerminalCommandURLRouter {
  static func handle(_ url: URL) {
    guard url.scheme?.lowercased() == "fahhplayer" else {
      return
    }

    let host = url.host?.lowercased()
    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

    guard host == "command-not-found" || path == "command-not-found" else {
      return
    }

    NotificationCenter.default.post(name: .fahhPlayerTerminalCommandNotFound, object: nil)
  }
}

@main
struct FahhPlayerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var powerObserver = PowerObserver()
  @StateObject private var launchAtLoginController = LaunchAtLoginController()

  var body: some Scene {
    MenuBarExtra {
      ContentView()
        .environmentObject(powerObserver)
        .environmentObject(launchAtLoginController)
    } label: {
      Image("StatusBarIcon")
        .renderingMode(.original)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    .menuBarExtraStyle(.window)
  }
}
