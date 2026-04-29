//
//  FahhPlayerApp.swift
//  FahhPlayer
//
//  Created by Pyae Phyo Win on 4/29/26.
//

import SwiftUI

@main
struct FahhPlayerApp: App {
    @StateObject private var powerObserver = PowerObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(powerObserver)
        }

        Settings {
            SoundControlPanel()
                .environmentObject(powerObserver)
                .padding(24)
                .frame(width: 440)
        }
    }
}
