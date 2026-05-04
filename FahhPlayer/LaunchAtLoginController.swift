//
//  LaunchAtLoginController.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
  @Published private(set) var isEnabled = false
  @Published private(set) var statusDescription = "Launch at login is off."
  @Published private(set) var errorMessage: String?

  init() {
    refreshStatus()
  }

  func setEnabled(_ enabled: Bool) {
    errorMessage = nil

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    refreshStatus()
  }

  func refreshStatus() {
    switch SMAppService.mainApp.status {
    case .enabled:
      isEnabled = true
      statusDescription = "FahhPlayer is enabled in Login Items."
    case .notRegistered:
      isEnabled = false
      statusDescription = "Launch at login is off."
    case .requiresApproval:
      isEnabled = false
      statusDescription = "macOS needs approval in System Settings > General > Login Items."
    case .notFound:
      isEnabled = false
      statusDescription = "Launch at login is unavailable for this build."
    @unknown default:
      isEnabled = false
      statusDescription = "Launch at login status is unavailable."
    }
  }
}
