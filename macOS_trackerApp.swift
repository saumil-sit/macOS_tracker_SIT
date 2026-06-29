//
//  macOS_trackerApp.swift
//  macOS_tracker
//
//  Created by Saumil on 09/04/26.
//

import SwiftUI

@main
struct macOS_trackerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

