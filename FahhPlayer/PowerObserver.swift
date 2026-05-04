//
//  PowerObserver.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import AVFoundation
import AppKit
import Combine
import Foundation
import IOKit.ps
import SwiftUI
import UniformTypeIdentifiers

enum SoundEvent: String, CaseIterable, Identifiable {
  case powerSupply
  case terminalCommandError

  var id: String { rawValue }

  var title: String {
    switch self {
    case .powerSupply:
      return "Power Supply Sound"
    case .terminalCommandError:
      return "Terminal Command Error Sound"
    }
  }

  var modeDescription: String {
    switch self {
    case .powerSupply:
      return "AC power switches to battery"
    case .terminalCommandError:
      return "Terminal command is not found"
    }
  }

  var iconName: String {
    switch self {
    case .powerSupply:
      return "bolt.fill"
    case .terminalCommandError:
      return "terminal.fill"
    }
  }

  fileprivate var customSoundFileNameKey: String {
    switch self {
    case .powerSupply:
      return "CustomPowerSoundFileName"
    case .terminalCommandError:
      return "CustomTerminalCommandErrorSoundFileName"
    }
  }

  fileprivate var destinationBaseName: String {
    switch self {
    case .powerSupply:
      return "CustomPowerSound"
    case .terminalCommandError:
      return "CustomTerminalCommandErrorSound"
    }
  }
}

extension Notification.Name {
  static let fahhPlayerTerminalCommandNotFound = Notification.Name(
    "FahhPlayerTerminalCommandNotFound")
}

final class PowerObserver: ObservableObject {
  @Published private(set) var powerSupplySoundName: String
  @Published private(set) var terminalCommandErrorSoundName: String
  private let legacyCustomSoundFileNameKey = "CustomSoundFileName"

  // Track last known power state to only play on transitions
  private var lastPowerSourceState: String?
  private var powerRunLoopSource: CFRunLoopSource?
  private var notificationObservers: [NSObjectProtocol] = []

  // Audio player for playback (replaces external afplay process)
  private var audioPlayer: AVAudioPlayer?

  init() {
    powerSupplySoundName = Self.defaultSoundName
    terminalCommandErrorSoundName = Self.defaultSoundName
    migrateLegacyPowerSoundPreference()
    loadSavedSoundNames()
    registerTerminalCommandObserver()
    registerPowerObserver()
    // Initialize last state to avoid playing immediately on first callback
    lastPowerSourceState = readPowerSourceState()
  }

  deinit {
    if let powerRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerRunLoopSource, .defaultMode)
    }
    notificationObservers.forEach(NotificationCenter.default.removeObserver)
  }

  static var defaultSoundName: String {
    bundledDefaultSoundURL() == nil ? "System Alert" : "Bundled Fahh"
  }

  func soundName(for event: SoundEvent) -> String {
    switch event {
    case .powerSupply:
      return powerSupplySoundName
    case .terminalCommandError:
      return terminalCommandErrorSoundName
    }
  }

  func hasCustomSound(for event: SoundEvent) -> Bool {
    customSoundURL(for: event) != nil
  }

  // MARK: - File Selection & Bookmarking
  func selectCustomSound(for event: SoundEvent) {
    activateForegroundUI()

    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.mp3, .wav, .audio]
    panel.title = "Choose \(event.title)"
    panel.message =
      "Select an MP3, WAV, or standard macOS audio file for \(event.modeDescription.lowercased())."

    if panel.runModal() == .OK, let url = panel.url {
      importCustomSound(from: url, for: event)
    }
  }

  private func importCustomSound(from url: URL, for event: SoundEvent) {
    let startedAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if startedAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let importedURL = try persistCustomSound(from: url, for: event)
      UserDefaults.standard.set(importedURL.lastPathComponent, forKey: event.customSoundFileNameKey)
      setSoundName(importedURL.lastPathComponent, for: event)
    } catch {
      presentAlert(
        message: "Couldn’t import selected sound", info: error.localizedDescription, buttons: ["OK"]
      )
    }
  }

  // MARK: - Playback
  func testSound(for event: SoundEvent) {
    playSound(for: event)
  }

  func playSound(for event: SoundEvent, showsPlaybackErrors: Bool = true) {
    if let url = customSoundURL(for: event) {
      do {
        try play(url: url)
        return
      } catch {
        if showsPlaybackErrors {
          presentAlert(
            message: "Couldn’t open saved sound", info: error.localizedDescription, buttons: ["OK"])
        }
        // Fall through to default sound
      }
    }

    // Fallback to default bundled sound
    if let defaultURL = Self.bundledDefaultSoundURL() {
      do {
        try play(url: defaultURL)
      } catch {
        if showsPlaybackErrors {
          presentAlert(
            message: "Failed to play default sound", info: error.localizedDescription,
            buttons: ["OK"])
        }
      }
    } else {
      NSSound.beep()
    }
  }

  private func play(url: URL) throws {
    // Stop previous playback
    audioPlayer?.stop()
    audioPlayer = nil

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      player.play()
      self.audioPlayer = player
    } catch {
      throw error
    }
  }

  func resetToDefault(for event: SoundEvent) {
    if let url = customSoundURL(for: event) {
      try? FileManager.default.removeItem(at: url)
    }
    UserDefaults.standard.removeObject(forKey: event.customSoundFileNameKey)
    setSoundName(Self.defaultSoundName, for: event)
  }

  private func loadSavedSoundNames() {
    for event in SoundEvent.allCases {
      setSoundName(
        customSoundURL(for: event)?.lastPathComponent ?? Self.defaultSoundName, for: event)
    }
  }

  private func customSoundURL(for event: SoundEvent) -> URL? {
    guard let fileName = UserDefaults.standard.string(forKey: event.customSoundFileNameKey) else {
      return nil
    }

    let candidateURL = customSoundStorageDirectory().appendingPathComponent(fileName)
    return FileManager.default.fileExists(atPath: candidateURL.path) ? candidateURL : nil
  }

  private func persistCustomSound(from sourceURL: URL, for event: SoundEvent) throws -> URL {
    let fileManager = FileManager.default
    let destinationDirectory = customSoundStorageDirectory()
    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

    let fileExtension = sourceURL.pathExtension.isEmpty ? "mp3" : sourceURL.pathExtension
    let destinationURL = destinationDirectory.appendingPathComponent(event.destinationBaseName)
      .appendingPathExtension(fileExtension)

    if let existingURL = customSoundURL(for: event), existingURL != destinationURL {
      try? fileManager.removeItem(at: existingURL)
    }

    if fileManager.fileExists(atPath: destinationURL.path) {
      try fileManager.removeItem(at: destinationURL)
    }

    try fileManager.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
  }

  private func setSoundName(_ soundName: String, for event: SoundEvent) {
    switch event {
    case .powerSupply:
      powerSupplySoundName = soundName
    case .terminalCommandError:
      terminalCommandErrorSoundName = soundName
    }
  }

  private func migrateLegacyPowerSoundPreference() {
    let defaults = UserDefaults.standard
    guard defaults.string(forKey: SoundEvent.powerSupply.customSoundFileNameKey) == nil,
      let legacyFileName = defaults.string(forKey: legacyCustomSoundFileNameKey)
    else {
      return
    }

    defaults.set(legacyFileName, forKey: SoundEvent.powerSupply.customSoundFileNameKey)
  }

  private func customSoundStorageDirectory() -> URL {
    let baseDirectory =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return baseDirectory.appendingPathComponent(
      Bundle.main.bundleIdentifier ?? "FahhPlayer", isDirectory: true)
  }

  private static func bundledDefaultSoundURL() -> URL? {
    for fileExtension in ["wav", "aiff", "mp3"] {
      if let url = Bundle.main.url(forResource: "fahhhhh", withExtension: fileExtension) {
        return url
      }
    }
    return nil
  }

  // C-compatible callback for IOPS notifications
  private static let powerSourceCallback: @convention(c) (UnsafeMutableRawPointer?) -> Void = {
    context in
    guard let context = context else { return }
    let observer = Unmanaged<PowerObserver>.fromOpaque(context).takeUnretainedValue()

    let newState = observer.readPowerSourceState()
    let ac = kIOPSACPowerValue as String
    let battery = kIOPSBatteryPowerValue as String

    // Only play when transitioning AC → Battery
    let shouldPlay = (observer.lastPowerSourceState == ac && newState == battery)
    // Update last state regardless
    observer.lastPowerSourceState = newState

    if shouldPlay {
      DispatchQueue.main.async {
        observer.playSound(for: .powerSupply)
      }
    }
  }

  // MARK: - Terminal Command Monitoring
  private func registerTerminalCommandObserver() {
    let observer = NotificationCenter.default.addObserver(
      forName: .fahhPlayerTerminalCommandNotFound,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.playSound(for: .terminalCommandError, showsPlaybackErrors: false)
    }
    notificationObservers.append(observer)
  }

  // MARK: - Power Source Monitoring (play only on AC → Battery transitions)
  func registerPowerObserver() {
    // Pass the static callback for the run loop source
    guard
      let runLoopSource = IOPSNotificationCreateRunLoopSource(
        PowerObserver.powerSourceCallback,
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )?.takeRetainedValue()
    else {
      presentAlert(
        message: "Power monitoring unavailable",
        info: "The app could not register for power source notifications.", buttons: ["OK"])
      return
    }
    powerRunLoopSource = runLoopSource
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
  }

  private func readPowerSourceState() -> String? {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    for source in sources {
      if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue()
        as? [String: Any],
        let state = description[kIOPSPowerSourceStateKey as String] as? String
      {
        return state  // e.g., kIOPSACPowerValue or kIOPSBatteryPowerValue
      }
    }
    return nil
  }

  // MARK: - Alerts
  @discardableResult
  private func presentAlert(message: String, info: String, buttons: [String])
    -> NSApplication.ModalResponse
  {
    activateForegroundUI()

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = message
    alert.informativeText = info
    for title in buttons { alert.addButton(withTitle: title) }
    return alert.runModal()
  }

  private func activateForegroundUI() {
    NSApp.activate(ignoringOtherApps: true)
  }
}
