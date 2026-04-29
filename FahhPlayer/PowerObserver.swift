//
//  PowerObserver.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit
import AVFoundation
import IOKit.ps
import UniformTypeIdentifiers

final class PowerObserver: ObservableObject {
    @Published var currentSoundName: String
    private let customSoundFileNameKey = "CustomSoundFileName"

    // Track last known power state to only play on transitions
    private var lastPowerSourceState: String?
    private var powerRunLoopSource: CFRunLoopSource?

    // Audio player for playback (replaces external afplay process)
    private var audioPlayer: AVAudioPlayer?

    init() {
        currentSoundName = Self.defaultSoundName
        loadSavedSoundName()
        registerPowerObserver()
        // Initialize last state to avoid playing immediately on first callback
        lastPowerSourceState = readPowerSourceState()
    }

    deinit {
        if let powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerRunLoopSource, .defaultMode)
        }
    }

    static var defaultSoundName: String {
        bundledDefaultSoundURL() == nil ? "System Alert" : "Bundled Fahh"
    }

    var hasCustomSound: Bool {
        customSoundURL != nil
    }

    // MARK: - File Selection & Bookmarking
    func selectCustomSound() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.mp3, .wav, .audio]
        panel.title = "Choose a sound file"
        panel.message = "Select an MP3 or WAV file to play on power events."

        if panel.runModal() == .OK, let url = panel.url {
            importCustomSound(from: url)
        }
    }

    private func importCustomSound(from url: URL) {
        let startedAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let importedURL = try persistCustomSound(from: url)
            UserDefaults.standard.set(importedURL.lastPathComponent, forKey: customSoundFileNameKey)
            currentSoundName = importedURL.lastPathComponent
        } catch {
            presentAlert(message: "Couldn’t import selected sound", info: error.localizedDescription, buttons: ["OK"])
        }
    }

    // MARK: - Playback
    func testSound() {
        playSound()
    }

    func playSound() {
        if let url = customSoundURL {
            do {
                try play(url: url)
                return
            } catch {
                presentAlert(message: "Couldn’t open saved sound", info: error.localizedDescription, buttons: ["OK"])
                // Fall through to default sound
            }
        }

        // Fallback to default bundled sound
        if let defaultURL = Self.bundledDefaultSoundURL() {
            do {
                try play(url: defaultURL)
            } catch {
                presentAlert(message: "Failed to play default sound", info: error.localizedDescription, buttons: ["OK"])
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

    func resetToDefault() {
        if let customSoundURL {
            try? FileManager.default.removeItem(at: customSoundURL)
        }
        UserDefaults.standard.removeObject(forKey: customSoundFileNameKey)
        currentSoundName = Self.defaultSoundName
    }

    private func loadSavedSoundName() {
        if let customSoundURL {
            currentSoundName = customSoundURL.lastPathComponent
        }
    }

    private var customSoundURL: URL? {
        guard let fileName = UserDefaults.standard.string(forKey: customSoundFileNameKey) else {
            return nil
        }

        let candidateURL = customSoundStorageDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: candidateURL.path) ? candidateURL : nil
    }

    private func persistCustomSound(from sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let destinationDirectory = customSoundStorageDirectory()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp3" : sourceURL.pathExtension
        let destinationURL = destinationDirectory.appendingPathComponent("CustomPowerSound").appendingPathExtension(fileExtension)

        let existingFiles = try? fileManager.contentsOfDirectory(at: destinationDirectory, includingPropertiesForKeys: nil)
        existingFiles?.forEach { existingURL in
            if existingURL.lastPathComponent != destinationURL.lastPathComponent {
                try? fileManager.removeItem(at: existingURL)
            }
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func customSoundStorageDirectory() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory.appendingPathComponent(Bundle.main.bundleIdentifier ?? "FahhPlayer", isDirectory: true)
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
    private static let powerSourceCallback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
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
                observer.playSound()
            }
        }
    }

    // MARK: - Power Source Monitoring (play only on AC → Battery transitions)
    func registerPowerObserver() {
        // Pass the static callback for the run loop source
        guard let runLoopSource = IOPSNotificationCreateRunLoopSource(
            PowerObserver.powerSourceCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )?.takeRetainedValue() else {
            presentAlert(message: "Power monitoring unavailable", info: "The app could not register for power source notifications.", buttons: ["OK"])
            return
        }
        powerRunLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }

    private func readPowerSourceState() -> String? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
               let state = description[kIOPSPowerSourceStateKey as String] as? String {
                return state // e.g., kIOPSACPowerValue or kIOPSBatteryPowerValue
            }
        }
        return nil
    }

    // MARK: - Alerts
    @discardableResult
    private func presentAlert(message: String, info: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = info
        for title in buttons { alert.addButton(withTitle: title) }
        return alert.runModal()
    }
}
