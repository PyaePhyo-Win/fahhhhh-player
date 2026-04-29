//
//  ContentView.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FahhPlayer")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Choose the sound that plays when your Mac switches from AC power to battery.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            SoundControlPanel()

            Label("Power monitoring is active as soon as the app launches.", systemImage: "bolt.badge.clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 500, idealWidth: 540, minHeight: 320)
    }
}

struct SoundControlPanel: View {
    @EnvironmentObject private var powerObserver: PowerObserver

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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

            HStack(spacing: 12) {
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
}
