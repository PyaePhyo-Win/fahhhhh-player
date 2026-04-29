//
//  ContentView.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image("StatusBarIcon")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Text("FahhPlayer")
                        .font(.title2.weight(.semibold))
                }

                Text("Runs in the menu bar and plays your sound when AC power switches to battery.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SoundControlPanel()

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { launchAtLoginController.setEnabled($0) }
                    ))

                    Text(launchAtLoginController.statusDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let errorMessage = launchAtLoginController.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Startup", systemImage: "power.circle.fill")
            }

            Divider()

            HStack {
                Label("Power monitoring becomes active as soon as the app launches.", systemImage: "bolt.badge.clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}

struct SoundControlPanel: View {
    @EnvironmentObject private var powerObserver: PowerObserver

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Current sound") {
                        Text(powerObserver.currentSoundName)
                            .fontWeight(.semibold)
                    }

                    LabeledContent("Mode") {
                        Text(powerObserver.hasCustomSound ? "Custom file" : "Bundled fallback")
                    }

                    LabeledContent("Fallback") {
                        Text(PowerObserver.defaultSoundName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Sound Setup", systemImage: "speaker.wave.3.fill")
            }

            HStack(spacing: 10) {
                Button("Choose Sound") {
                    powerObserver.selectCustomSound()
                }
                .buttonStyle(.borderedProminent)

                Button("Test Playback") {
                    powerObserver.testSound()
                }

                Button("Reset to Default") {
                    powerObserver.resetToDefault()
                }
                .disabled(!powerObserver.hasCustomSound)
            }

            Text("Supported formats: MP3, WAV, and other standard macOS audio files the system can decode.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PowerObserver())
        .environmentObject(LaunchAtLoginController())
}
