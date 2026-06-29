//
//  ContentView.swift
//  macOS_tracker
//
//  Created by Saumil on 09/04/26.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var manager: USBMonitorManager
    @State private var snapshot: SystemSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if let snap = snapshot {

                    // MARK: Device Info
                    section("📊 Device Info") {
                        infoRow("Host", snap.DeviceInfo.HostName)
                        infoRow("Model", snap.DeviceInfo.Model)
                        infoRow("Serial", snap.DeviceInfo.SerialNumber)
                        infoRow("OS", snap.OperatingSystem.Edition)
                    }
                    
                    Divider()

                    // MARK: Processor & Memory
                    section("💻 Hardware") {
                        infoRow("CPU", snap.Processor.Name)
                        infoRow("Cores", "\(snap.Processor.PhysicalCores)")
                        infoRow("RAM", snap.Memory.TotalReadable)
                        infoRow("GPU", snap.Graphics.GpuName)
                    }
                    
                    Divider()

                    // MARK: Peripherals
                    section("🔌 Connected USB Devices") {
                        deviceList("Keyboard", snap.Peripherals.Keyboards)
                        deviceList("Mouse", snap.Peripherals.PointingDevices)
                        deviceList("Others", snap.Peripherals.OtherDevices)
                    }
                    
                    Divider()

                    // MARK: Storage
                    section("💾 Storage") {
                        ForEach(snap.Storage.Disks, id: \.Model) { disk in
                            VStack(alignment: .leading) {
                                Text(disk.Model).font(.headline)
                                Text("Size: \(disk.SizeReadable)")
                                Text("Used: \(disk.UsedSizeReadable)")
                                Text("Free: \(disk.FreeSizeReadable)")
                            }
                            Divider()
                        }
                    }

                    // MARK: Software
                    section("📦 Software (\(snap.Software.TotalInstalled))") {
                        ForEach(snap.Software.Details.prefix(100), id: \.Name) { app in
                            HStack {
                                Text(app.Name)
                                Spacer()
                                Text(app.Version)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Divider()
                }

                // MARK: Logs
                section("📜 Logs") {
                    ForEach(manager.logs.prefix(50), id: \.self) { log in
                        Text(log)
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
        .frame(width: 520, height: 600)
        .onAppear {
            updateSnapshot()
        }
        .onChange(of: manager.devices) { _ in
            updateSnapshot()
        }
    }

    // MARK: Helpers

    private func updateSnapshot() {
        DispatchQueue.global(qos: .utility).async {
            let snap = buildSystemSnapshot(devices: manager.devices)
            DispatchQueue.main.async {
                self.snapshot = snap
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title + ":")
                .fontWeight(.semibold)
            Text(value)
        }
    }

    private func deviceList(_ title: String, _ devices: [SystemSnapshot.Peripherals.Device]) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline)
            if devices.isEmpty {
                Text("None").foregroundColor(.gray)
            } else {
                ForEach(devices, id: \.Name) { d in
                    Text(d.Name ?? "Unknown")
                }
            }
        }
    }
}
