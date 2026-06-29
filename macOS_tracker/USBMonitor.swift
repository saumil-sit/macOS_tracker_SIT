//
//  USBMonitor.swift
//  macOS_tracker
//
//  Created by Saumil on 09/04/26.
//

import Foundation
import IOKit
import IOKit.usb
import UserNotifications
import CoreGraphics

struct SystemSnapshot: Codable {

    struct DeviceInfo: Codable {
        let HostName: String
        let FullQualifiedName: String
        let DeviceId: String
        let Manufacturer: String
        let Model: String
        let SerialNumber: String
        let SystemType: String
    }

    struct OperatingSystem: Codable {
        let Edition: String
    }

    struct UserInfo: Codable {
        let AssignedUsers: [String]
    }

    struct Processor: Codable {
        let Name: String
        let Manufacturer: String
        let PhysicalCores: Int
        let LogicalProcessors: Int
    }

    struct Memory: Codable {
        struct Module: Codable {
            let Slot: String
            let CapacityBytes: UInt64
            let CapacityReadable: String
            let SpeedMHz: Int
            let Manufacturer: String
            let PartNumber: String
        }

        let TotalBytes: UInt64
        let TotalReadable: String
        let Modules: [Module]
    }

    struct Graphics: Codable {
        let GpuName: String
    }

    struct Storage: Codable {
        struct Disk: Codable {
            let Model: String
            let SerialNumber: String
            let SizeBytes: UInt64
            let SizeReadable: String
            let DriveLetters: [String]
            let FreeSizeBytes: UInt64
            let FreeSizeReadable: String
            let UsedSizeBytes: UInt64
            let UsedSizeReadable: String
            let Interface: String?
            let MediaType: String
            let IsSSD: Bool
            let FileSystems: [String]
        }

        let TotalBytes: UInt64
        let UsedBytes: UInt64
        let TotalReadable: String
        let UsedReadable: String
        let Disks: [Disk]
    }

    struct Peripherals: Codable {
        struct Device: Codable {
            let Name: String?
            let Manufacturer: String?
            let Slot: String?
            let SerialNumber: String?
        }

        let Keyboards: [Device]
        let PointingDevices: [Device]
        let WebCamDevices: [Device]
        let AudioDevices: [Device]
        let OtherDevices: [Device]
    }

    struct Display: Codable {
        struct Monitor: Codable {
            let Brand: String
            let Model: String
            let SerialNumber: String
        }

        let MonitorCount: Int
        let Monitors: [Monitor]
    }

    struct Software: Codable {
        struct App: Codable {
            let Name: String
            let Version: String
            let InstallDate: String?
        }

        let TotalInstalled: Int
        let Details: [App]
    }

    struct Audit: Codable {
        let ScanTimestamp: String
    }

    let DeviceInfo: DeviceInfo
    let OperatingSystem: OperatingSystem
    let UserInfo: UserInfo
    let Processor: Processor
    let Memory: Memory
    let Graphics: Graphics
    let Storage: Storage
    let Peripherals: Peripherals
    let Display: Display
    let Software: Software
    let Audit: Audit
}


private func getHostName() -> String {
    Host.current().localizedName ?? ProcessInfo.processInfo.hostName
}

private func getModelIdentifier() -> String? {
    var size: size_t = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    if sysctlbyname("hw.model", &model, &size, nil, 0) == 0 {
        return String(cString: model)
    }
    return nil
}

private func getSerialNumber() -> String? {
    let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    defer { if platformExpert != 0 { IOObjectRelease(platformExpert) } }
    guard platformExpert != 0 else { return nil }
    if let serial = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
        return serial
    }
    return nil
}

private func getCPUInfo() -> (brand: String?, vendor: String?, cores: Int?, logical: Int?) {
    func sysctlString(_ key: String) -> String? {
        var size: size_t = 0
        sysctlbyname(key, nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        if sysctlbyname(key, &buf, &size, nil, 0) == 0 {
            return String(cString: buf)
        }
        return nil
    }
    func sysctlInt(_ key: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(key, &value, &size, nil, 0) == 0 ? Int(value) : nil
    }
    
    let brand = sysctlString("machdep.cpu.brand_string")
    let vendor = sysctlString("machdep.cpu.vendor")
    let cores = sysctlInt("hw.physicalcpu")
    let logical = sysctlInt("hw.logicalcpu")
    return (brand, vendor, cores, logical)
}

private func getTotalRAM() -> UInt64? {
    return ProcessInfo.processInfo.physicalMemory
}

private func getGPUName() -> String? {
    let matching = IOServiceMatching("IOPCIDevice")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
    defer { IOObjectRelease(iterator) }
    
    var gpuName: String?
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        if let deviceNameData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Data,
           let name = String(data: deviceNameData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) {
            let lower = name.lowercased()
            if lower.contains("graphics") || lower.contains("gpu") || lower.contains("radeon") || lower.contains("intel") || lower.contains("nvidia") {
                gpuName = name
                break
            }
        }
    }
    return gpuName
}

private func getMonitorCount() -> Int {
    var displayCount: UInt32 = 0
    let max = UInt32(32)
    var online = [CGDirectDisplayID](repeating: 0, count: Int(max))
    CGGetOnlineDisplayList(max, &online, &displayCount)
    return Int(displayCount)
}

private func peripheralsFromSeenDevices(_ devices: Set<USBDevice>) -> [SystemSnapshot.Peripherals.Device] {
    return devices.map { dev in
        return SystemSnapshot.Peripherals.Device(
            Name: dev.name,
            Manufacturer: nil,
            Slot: nil,
            SerialNumber: nil
        )
    }
}

private func categorizeDevices(_ devices: Set<USBDevice>) -> (
    keyboards: [SystemSnapshot.Peripherals.Device],
    pointing: [SystemSnapshot.Peripherals.Device],
    others: [SystemSnapshot.Peripherals.Device]
) {
    
    var keyboards: [SystemSnapshot.Peripherals.Device] = []
    var pointing: [SystemSnapshot.Peripherals.Device] = []
    var others: [SystemSnapshot.Peripherals.Device] = []

    for dev in devices {
        let name = dev.name.lowercased()

        let device = SystemSnapshot.Peripherals.Device(
            Name: dev.name,
            Manufacturer: nil,
            Slot: nil,
            SerialNumber: nil
        )

        if name.contains("keyboard") {
            keyboards.append(device)
        } else if name.contains("mouse") || name.contains("trackpad") {
            pointing.append(device)
        } else {
            others.append(device)
        }
    }

    return (keyboards, pointing, others)
}

private func getStorageInfo() -> SystemSnapshot.Storage {
    
    let fileManager = FileManager.default
    
    let keys: [URLResourceKey] = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeIsInternalKey,
        .volumeIsRemovableKey
    ]
    
    guard let urls = fileManager.mountedVolumeURLs(
        includingResourceValuesForKeys: keys,
        options: []
    ) else {
        return emptyStorage()
    }
    
    var disks: [SystemSnapshot.Storage.Disk] = []
    
    for url in urls {
        
        // ✅ CRITICAL FILTER 1: ONLY /Volumes
        guard url.path.hasPrefix("/Volumes/") else { continue }
        
        // ❌ Skip system volume
        if url.path == "/Volumes/Macintosh HD" { continue }
        
        if let values = try? url.resourceValues(forKeys: Set(keys)) {
            
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacity ?? 0)
            let used = total - free
            
            // ❌ Skip invalid disks (0 size)
            if total == 0 { continue }
            
            let disk = SystemSnapshot.Storage.Disk(
                Model: values.volumeName ?? "External Disk",
                SerialNumber: "N/A",
                SizeBytes: total,
                SizeReadable: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file),
                DriveLetters: [url.path],
                FreeSizeBytes: free,
                FreeSizeReadable: ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file),
                UsedSizeBytes: used,
                UsedSizeReadable: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file),
                Interface: "USB",
                MediaType: "External",
                IsSSD: false,
                FileSystems: ["Unknown"]
            )
            
            disks.append(disk)
        }
    }
    
    let total = disks.reduce(0) { $0 + $1.SizeBytes }
    let used = disks.reduce(0) { $0 + $1.UsedSizeBytes }
    
    return SystemSnapshot.Storage(
        TotalBytes: total,
        UsedBytes: used,
        TotalReadable: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file),
        UsedReadable: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file),
        Disks: disks
    )
}

private func emptyStorage() -> SystemSnapshot.Storage {
    return SystemSnapshot.Storage(
        TotalBytes: 0,
        UsedBytes: 0,
        TotalReadable: "N/A",
        UsedReadable: "N/A",
        Disks: []
    )
}

private func getInstalledApps() -> SystemSnapshot.Software {
    
    let fileManager = FileManager.default
    
    let appPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications"
    ]
    
    var apps: [SystemSnapshot.Software.App] = []
    
    for path in appPaths {
        
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
        
        for item in items where item.hasSuffix(".app") {
            
            let fullPath = path + "/" + item
            
            let name = item.replacingOccurrences(of: ".app", with: "")
            
            let app = SystemSnapshot.Software.App(
                Name: name,
                Version: getAppVersion(path: fullPath),
                InstallDate: nil
            )
            
            apps.append(app)
        }
    }
    
    return SystemSnapshot.Software(
        TotalInstalled: apps.count,
        Details: apps
    )
}

private func getAppVersion(path: String) -> String {
    
    let infoPath = path + "/Contents/Info.plist"
    
    if let dict = NSDictionary(contentsOfFile: infoPath),
       let version = dict["CFBundleShortVersionString"] as? String {
        return version
    }
    
    return "Unknown"
}


func buildSystemSnapshot(devices: Set<USBDevice>) -> SystemSnapshot {
    
    let hostName = getHostName()
    let model = getModelIdentifier() ?? "Unknown"
    let serial = getSerialNumber() ?? "Unknown"
    let cpu = getCPUInfo()
    let totalRam = getTotalRAM() ?? 0
    let gpu = getGPUName() ?? "Unknown"
    let monitorCount = getMonitorCount()
    
    let iso = ISO8601DateFormatter().string(from: Date())
    
    let usbDevices = peripheralsFromSeenDevices(devices)
    
    let categorized = categorizeDevices(devices)
    
    let storage = getStorageInfo()
    
    let software = getInstalledApps()
    
    
    return SystemSnapshot(
        
        DeviceInfo: .init(
            HostName: hostName,
            FullQualifiedName: hostName,
            DeviceId: UUID().uuidString,
            Manufacturer: "Apple Inc.",
            Model: model,
            SerialNumber: serial,
            SystemType: "macOS"
        ),
        
        OperatingSystem: .init(
            Edition: "macOS"
        ),
        
        UserInfo: .init(
            AssignedUsers: [NSUserName()]
        ),
        
        Processor: .init(
            Name: cpu.brand ?? "Unknown",
            Manufacturer: cpu.vendor ?? "Unknown",
            PhysicalCores: cpu.cores ?? 0,
            LogicalProcessors: cpu.logical ?? 0
        ),
        
        Memory: .init(
            TotalBytes: totalRam,
            TotalReadable: ByteCountFormatter.string(fromByteCount: Int64(totalRam), countStyle: .memory),
            Modules: [] // macOS doesn't easily expose this
        ),
        
        Graphics: .init(
            GpuName: gpu
        ),
        
        Storage: storage,
        
        Peripherals: .init(
            Keyboards: categorized.keyboards,
            PointingDevices: categorized.pointing,
            WebCamDevices: [],
            AudioDevices: [],
            OtherDevices: categorized.others
        ),
        
        Display: .init(
            MonitorCount: monitorCount,
            Monitors: []
        ),
        
        Software: software,
        
        Audit: .init(
            ScanTimestamp: iso
        )
    )
}

private func logSnapshotJSON(devices: Set<USBDevice>) {

    let system = buildSystemSnapshot(devices: devices)
    let inventory = system.toInventorySnapshot()

    do {
        let data = try InventorySnapshot.encode(inventory)

        if let pretty = data.prettyJSONString {
            print("\n========== INVENTORY JSON ==========")
            print(pretty)
            print("====================================\n")
        }
    } catch {
        print("❌ Failed to encode inventory: \(error)")
        return
    }

    Task {
        do {
            let api = HardwareAPI()

            let result = try await api.postHardware(
                snapshot: inventory,
                to: "http://192.168.1.9:2023"
            )

            let bytes = result.data?.count ?? 0

            print("✅ Logged successfully (status: \(result.statusCode), \(bytes) bytes)")

        } catch {
            print("❌ Failed to post inventory snapshot:")
            print(error.localizedDescription)
        }
    }
}

struct USBDevice: Hashable, Sendable {
    let vendorId: Int
    let productId: Int
    let name: String
    
    // Make Hashable conformance explicitly nonisolated to avoid main-actor isolated synthesis
    nonisolated static func == (lhs: USBDevice, rhs: USBDevice) -> Bool {
        lhs.vendorId == rhs.vendorId && lhs.productId == rhs.productId && lhs.name == rhs.name
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(vendorId)
        hasher.combine(productId)
        hasher.combine(name)
    }
}

class USBMonitor {
    
    // MARK: - Public
    
    static let shared = USBMonitor()
    
    var onEvent: ((USBDevice, String) -> Void)?
    
    private var isActive = true
    
    //    var seenDevicesExposed: Set<USBDevice> {
    //        return seenDevices
    //    }
    
    // MARK: - Control
    func stop() {
        isActive = false
        onEvent = nil
        cleanup()
    }
    
    // MARK: - Private
    //private var seenDevices = Set<USBDevice>()
    //private let queue = DispatchQueue(label: "usb.monitor.thread.safe")
    
    private var notificationPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    // Retained refcon for IOKit callbacks
    private var refconPointer: UnsafeMutableRawPointer?
    private var didReleaseRefcon = false
    
    // MARK: - Init
    private init() {         
        setupNotifications()
        loadExistingDevices()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort else { return }
        
        guard let unmanagedSource = IONotificationPortGetRunLoopSource(notificationPort) else { return }
        
        let source = unmanagedSource.takeUnretainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        
        //let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        self.refconPointer = refcon
        
        // CONNECT
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            IOServiceMatching(kIOUSBDeviceClassName),
            { (refcon, iterator) in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleAdded(iterator)
            },
            refcon,
            &addedIterator
        )
        
        handleAdded(addedIterator)
        
        // DISCONNECT
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            IOServiceMatching(kIOUSBDeviceClassName),
            { (refcon, iterator) in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleRemoved(iterator)
            },
            refcon,
            &removedIterator
        )
        
        handleRemoved(removedIterator)
    }
    
    private func loadExistingDevices() {
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        
        var iterator: io_iterator_t = 0
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS {
            
            var device = IOIteratorNext(iterator)
            
            while device != 0 {
                
                let vendor = getInt(device, "idVendor")
                let product = getInt(device, "idProduct")
                let name = getString(device, "USB Product Name") ?? "Unknown Device"
                
                let usbDevice = USBDevice(vendorId: vendor, productId: product, name: name)
                
                //                queue.sync {
                //                    self.seenDevices.insert(usbDevice)
                //                }
                
                Task {
                    await USBMonitorActor.shared.addDevice(usbDevice)
                }
                
                IOObjectRelease(device)
                device = IOIteratorNext(iterator)
            }
            
            IOObjectRelease(iterator)
        }
    }
    
    // MARK: - Handlers
    //    private func handleAdded(_ iterator: io_iterator_t) {
    //
    //        var device = IOIteratorNext(iterator)
    //
    //        while device != 0 {
    //
    //            let vendor = getInt(device, "idVendor")
    //            let product = getInt(device, "idProduct")
    //            let name = getString(device, "USB Product Name") ?? "Unknown Device"
    //
    //            let usbDevice = USBDevice(vendorId: vendor, productId: product, name: name)
    //
    //            queue.async { [weak self] in
    //                guard let self else { return }
    //                guard self.isActive else { return }
    //
    //                if !self.seenDevices.contains(usbDevice) {
    //                    self.seenDevices.insert(usbDevice)
    //
    //                    DispatchQueue.main.async {
    //                        self.emitEvent(device: usbDevice, type: "connected")
    //                    }
    //                }
    //            }
    //
    //            IOObjectRelease(device)
    //            device = IOIteratorNext(iterator)
    //        }
    //    }
    //
    //    private func handleRemoved(_ iterator: io_iterator_t) {
    //
    //        var device = IOIteratorNext(iterator)
    //
    //        while device != 0 {
    //
    //            let vendor = getInt(device, "idVendor")
    //            let product = getInt(device, "idProduct")
    //
    //            queue.async { [weak self] in
    //                guard let self else { return }
    //                guard self.isActive else { return }
    //
    //                if let existing = self.seenDevices.first(where: {
    //                    $0.vendorId == vendor && $0.productId == product
    //                }) {
    //                    self.seenDevices.remove(existing)
    //
    //                    DispatchQueue.main.async {
    //                        self.emitEvent(device: existing, type: "disconnected")
    //                    }
    //                }
    //            }
    //
    //            IOObjectRelease(device)
    //            device = IOIteratorNext(iterator)
    //        }
    //    }
    
    private func handleAdded(_ iterator: io_iterator_t) {
        
        var device = IOIteratorNext(iterator)
        
        while device != 0 {
            
            let vendor = getInt(device, "idVendor")
            let product = getInt(device, "idProduct")
            let name = getString(device, "USB Product Name") ?? "Unknown Device"
            
            let usbDevice = USBDevice(vendorId: vendor, productId: product, name: name)
            
            Task { [weak self] in
                guard let self else { return }
                
                let inserted = await USBMonitorActor.shared.addDevice(usbDevice)
                
                if inserted {
                    await MainActor.run {
                        guard self.isActive else { return }
                        self.emitEvent(device: usbDevice, type: "connected")
                    }
                }
            }
            
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func handleRemoved(_ iterator: io_iterator_t) {
        
        var device = IOIteratorNext(iterator)
        
        while device != 0 {
            
            let vendor = getInt(device, "idVendor")
            let product = getInt(device, "idProduct")
            
            Task { [weak self] in
                guard let self else { return }
                
                if let removed = await USBMonitorActor.shared.removeDevice(vendor: vendor, product: product) {
                    await MainActor.run {
                        guard self.isActive else { return }
                        self.emitEvent(device: removed, type: "disconnected")
                    }
                }
            }
            
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    // MARK: - Emit (SAFE)
    //    private func emitEvent(device: USBDevice, type: String) {
    //        guard isActive else { return }
    //
    //        // Notification (main thread)
    //        DispatchQueue.main.async {
    //            self.showNotification(text: "\(type.capitalized): \(device.name)")
    //        }
    //
    //        // Snapshot logging (background)
    //        DispatchQueue.global(qos: .utility).async { [weak self] in
    //            guard let self else { return }
    //            let snapshot = self.seenDevices
    //            logSnapshotJSON(devices: snapshot)
    //        }
    //
    //        // Callback (deliver on next runloop turn, main queue)
    //        DispatchQueue.main.async { [weak self] in
    //            guard let self, self.isActive else { return }
    //            self.onEvent?(device, type)
    //        }
    //    }
    
    private func emitEvent(device: USBDevice, type: String) {
        
        guard isActive else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showNotification(text: "\(type.capitalized): \(device.name)")
        }
        
        Task { [weak self] in
            guard let self else { return }

            let devices = await USBMonitorActor.shared.getDevices()

            let systemSnapshot = buildSystemSnapshot(devices: devices)
            let inventory = systemSnapshot.toInventorySnapshot()

            do {
                let api = HardwareAPI()

                _ = try await api.postHardware(
                    snapshot: inventory,
                    to: "http://192.168.1.9:2023"
                )
            } catch {
                print(error)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isActive else { return }
            self.onEvent?(device, type)
        }
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        isActive = false
        
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            runLoopSource = nil
        }
        
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        
        if let refconPointer, !didReleaseRefcon {
            //Unmanaged<USBMonitor>.fromOpaque(refconPointer).release()
            didReleaseRefcon = true
            self.refconPointer = nil
        }
    }
    
    // MARK: - Helpers
    private func getInt(_ device: io_object_t, _ key: String) -> Int {
        if let val = IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
            return val as? Int ?? 0
        }
        return 0
    }
    
    private func getString(_ device: io_object_t, _ key: String) -> String? {
        if let val = IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
            return val as? String
        }
        return nil
    }
    
    private func showNotification(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Device Monitor"
        content.body = text
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
}

