//
//  USBMonitorManager.swift
//  macOS_tracker
//
//  Created by Saumil on 09/04/26.
//

import Foundation
import Combine

@MainActor
final class USBMonitorManager: ObservableObject {

    static let shared = USBMonitorManager()

    private let monitor = USBMonitor.shared

    @Published private(set) var logs: [String] = []
    @Published private(set) var devices: Set<USBDevice> = []

    private let logFileURL: URL

    private init() {

        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = folder.appendingPathComponent("usb_logs.txt")

        loadLogs()

        // ✅ IMPORTANT: Listen to events
        monitor.onEvent = { [weak self] device, type in
            self?.handleEvent(device: device, type: type)
        }

        // ✅ Initial load
        Task {
            let devices = await USBMonitorActor.shared.getDevices()
            self.devices = devices
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy hh:mm:ss a"  // ✅ AM/PM format
        return formatter.string(from: Date())
    }

    // MARK: - HANDLE EVENTS
    private func handleEvent(device: USBDevice, type: String) {

        let message = "\(formattedTime()): \(type.uppercased()) - \(device.name)"
        saveLog(message)

        Task {
            let devices = await USBMonitorActor.shared.getDevices()

            await MainActor.run {
                self.logs.insert(message, at: 0)
                self.devices = devices
            }
        }
    }

    // MARK: - REFRESH
    func refreshDevices() {
        Task {
            let devices = await USBMonitorActor.shared.getDevices()
            self.devices = devices
        }
    }

    // MARK: - LOG SAVE
    private func saveLog(_ text: String) {
        let line = text + "\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }

    // MARK: - LOAD LOGS
    private func loadLogs() {
        if let data = try? Data(contentsOf: logFileURL),
           let content = String(data: data, encoding: .utf8) {

            let lines = content.split(separator: "\n").map { String($0) }
            self.logs = lines.reversed()
        }
    }
}
