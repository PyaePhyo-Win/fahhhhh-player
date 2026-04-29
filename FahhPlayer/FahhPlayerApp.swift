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
    @StateObject private var launchAtLoginController = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(powerObserver)
                .environmentObject(launchAtLoginController)
                .frame(width: 360)
        } label: {
            Image("StatusBarIcon")
                .renderingMode(.original)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .menuBarExtraStyle(.window)
    }
}
