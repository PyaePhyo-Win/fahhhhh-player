//
//  ContentView.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController
    @State private var didCopyTerminalHook = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                    Text("Runs in the menu bar for power disconnects and missing terminal commands.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SoundControlPanel(event: .powerSupply)
                SoundControlPanel(event: .terminalCommandError)
                TerminalSetupPanel(didCopyTerminalHook: $didCopyTerminalHook)

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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 420)
        .frame(maxHeight: 620)
    }
}

struct SoundControlPanel: View {
    @EnvironmentObject private var powerObserver: PowerObserver
    let event: SoundEvent

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Current sound") {
                    Text(powerObserver.soundName(for: event))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                LabeledContent("Mode") {
                    Text(powerObserver.hasCustomSound(for: event) ? "Custom file" : "Bundled fallback")
                }

                LabeledContent("Fallback") {
                    Text(PowerObserver.defaultSoundName)
                }

                HStack(spacing: 10) {
                    Button("Choose") {
                        powerObserver.selectCustomSound(for: event)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test") {
                        powerObserver.testSound(for: event)
                    }

                    Button("Reset") {
                        powerObserver.resetToDefault(for: event)
                    }
                    .disabled(!powerObserver.hasCustomSound(for: event))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(event.title, systemImage: event.iconName)
        }
    }
}

struct TerminalSetupPanel: View {
    @Binding var didCopyTerminalHook: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button("Copy zsh Hook") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.zshHook, forType: .string)
                        didCopyTerminalHook = true
                    }

                    Button("Test Trigger") {
                        NSWorkspace.shared.open(Self.triggerURL)
                    }

                    if didCopyTerminalHook {
                        Text("Copied")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Add the hook to .zshrc to play the terminal sound when zsh cannot find a command.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Terminal Setup", systemImage: "terminal.fill")
        }
    }

    private static let triggerURL = URL(string: "fahhplayer://command-not-found")!

    private static let zshHook = """
command_not_found_handler() {
  open -g "fahhplayer://command-not-found"
  print -u2 "zsh: command not found: $1"
  return 127
}
"""
}

#Preview {
    ContentView()
        .environmentObject(PowerObserver())
        .environmentObject(LaunchAtLoginController())
}
