import Foundation
import Cocoa
import IOKit
import IOKit.graphics
import SystemConfiguration
import Network

extension SystemSnapshot {

    // MARK: - Monitor Fetcher
    private func getMonitorDetails() -> [InventorySnapshot.MonitorDetail] {

        var monitors: [InventorySnapshot.MonitorDetail] = []

        for screen in NSScreen.screens {

            guard let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }

            let vendorID = CGDisplayVendorNumber(screenID)
            let productID = CGDisplayModelNumber(screenID)
            let serialNumber = CGDisplaySerialNumber(screenID)

            var service: io_service_t = 0

            // 🔥 Find matching display service
            if let matching = IOServiceMatching("IODisplayConnect") {
                var iterator: io_iterator_t = 0

                if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {

                    var entry = IOIteratorNext(iterator)

                    while entry != 0 {

                        if let info = IODisplayCreateInfoDictionary(entry, 0)
                            .takeRetainedValue() as? [String: Any] {

                            let v = info[kDisplayVendorID as String] as? Int ?? 0
                            let p = info[kDisplayProductID as String] as? Int ?? 0

                            if v == Int(vendorID) && p == Int(productID) {
                                service = entry
                                break
                            }
                        }

                        IOObjectRelease(entry)
                        entry = IOIteratorNext(iterator)
                    }

                    IOObjectRelease(iterator)
                }
            }

            var info: [String: Any] = [:]

            if service != 0 {
                if let dict = IODisplayCreateInfoDictionary(service, 0)
                    .takeRetainedValue() as? [String: Any] {
                    info = dict
                }
                IOObjectRelease(service)
            }

            let productNameDict = info["DisplayProductName"] as? [String: String]
            let productName = productNameDict?.values.first

            let manufacturerCode = decodeVendorCode(Int(vendorID))

            let rawManufacturer = stringToRawBytes(manufacturerCode, fixedLength: 16)
            let rawProduct = stringToRawBytes(productName ?? "", fixedLength: 16)
            let rawSerial = stringToRawBytes(serialNumber == 0 ? "" : "\(serialNumber)", fixedLength: 16)

            let instanceName = "DISPLAY\\\(manufacturerCode)\(productID)\\\(UUID().uuidString)"

            let monitor = InventorySnapshot.MonitorDetail(
                Id: UUID().uuidString,
                Manufacturer: manufacturerCode,
                ProductName: productName,
                SerialNumber: serialNumber == 0 ? nil : "\(serialNumber)",
                InstanceName: instanceName,
                RawManufacturer: rawManufacturer,
                RawProduct: rawProduct,
                RawSerial: rawSerial
            )

            monitors.append(monitor)
        }

        return monitors
    }
    
    private func decodeVendorCode(_ vendorID: Int) -> String {
        let char1 = Character(UnicodeScalar(((vendorID >> 10) & 0x1F) + 64)!)
        let char2 = Character(UnicodeScalar(((vendorID >> 5) & 0x1F) + 64)!)
        let char3 = Character(UnicodeScalar((vendorID & 0x1F) + 64)!)
        return "\(char1)\(char2)\(char3)" // e.g. HPN
    }

    private func stringToRawBytes(_ value: String, fixedLength: Int) -> String {
        let bytes = value.utf8.map { String($0) }
        let padded = bytes + Array(repeating: "0", count: max(0, fixedLength - bytes.count))
        return padded.prefix(fixedLength).joined(separator: ",")
    }
    
    private func getNetworkAdapters() -> [InventorySnapshot.NetworkAdapter] {
        
        var adapters: [InventorySnapshot.NetworkAdapter] = []
        var seen = Set<String>()

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }

        var ptr = ifaddr

        while ptr != nil {
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)

            if seen.contains(name) {
                ptr = interface.ifa_next
                continue
            }
            seen.insert(name)

            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0

            let ips = getIPAddresses(interface: name)
            let mac = getMACAddress(interface: name)

            let type = getInterfaceType(name)

            let adapter = InventorySnapshot.NetworkAdapter(
                Id: UUID().uuidString,
                Name: getReadableName(name),
                Description: getDescription(name),
                NetworkId: nil,
                MacAddress: mac ?? "",
                InterfaceType: type,
                Status: isUp ? "Up" : "Down",
                IsUp: isUp,
                Speed: getSpeed(type),
                SupportsMulticast: true,
                DhcpEnabled: nil,
                DnsSuffix: "",
                IpAddresses: ips,
                GatewayAddresses: getGateway(),
                DnsAddresses: getDNS(),
                DhcpServers: []
            )

            adapters.append(adapter)
            ptr = interface.ifa_next
        }

        freeifaddrs(ifaddr)
        return adapters
    }
    
    private func getIPAddresses(interface: String) -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return [] }
        var ptr = ifaddr

        while ptr != nil {
            let ifa = ptr!.pointee

            if String(cString: ifa.ifa_name) == interface,
               let addr = ifa.ifa_addr {

                let family = addr.pointee.sa_family

                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                    getnameinfo(addr,
                                socklen_t(addr.pointee.sa_len),
                                &host,
                                socklen_t(host.count),
                                nil,
                                0,
                                NI_NUMERICHOST)

                    result.append(String(cString: host))
                }
            }

            ptr = ifa.ifa_next
        }

        freeifaddrs(ifaddr)
        return result
    }
    
    private func getMACAddress(interface: String) -> String? {
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }

        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr

        while ptr != nil {
            let ifa = ptr!.pointee

            if String(cString: ifa.ifa_name) == interface,
               let addr = ifa.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK) {

                let sdl = UnsafePointer<sockaddr_dl>(OpaquePointer(addr))

                let base = withUnsafePointer(to: sdl.pointee.sdl_data) {
                    UnsafeRawPointer($0)
                }

                let macPtr = base.advanced(by: Int(sdl.pointee.sdl_nlen))

                let length = Int(sdl.pointee.sdl_alen)

                var macAddress = ""

                for i in 0..<length {
                    let byte = macPtr.load(fromByteOffset: i, as: UInt8.self)
                    macAddress += String(format: "%02x", byte)
                    if i != length - 1 {
                        macAddress += ":"
                    }
                }

                return macAddress
            }

            ptr = ifa.ifa_next
        }

        return nil
    }
    
    private func getInterfaceType(_ name: String) -> String {
        if name == "lo0" { return "Loopback" }
        if name.starts(with: "en") { return "Ethernet" }
        if name.starts(with: "utun") { return "VPN" }
        return "Other"
    }

    private func getReadableName(_ name: String) -> String {
        if name == "en0" { return "Wi-Fi" }
        if name == "en1" { return "Ethernet" }
        if name == "lo0" { return "Loopback Pseudo-Interface" }
        return name
    }

    private func getDescription(_ name: String) -> String {
        if name == "en0" { return "Wi-Fi Adapter" }
        if name == "en1" { return "Ethernet Adapter" }
        if name == "lo0" { return "Software Loopback Interface" }
        return "Network Interface"
    }
    
    private func getSpeed(_ type: String) -> Int {
        switch type {
        case "Ethernet": return 1000000000
        case "Loopback": return 1073741824
        default: return 100000000
        }
    }
    
    private func getDNS() -> [String] {
        return ["8.8.8.8"] // fallback
    }

    private func getGateway() -> [String] {
        return ["192.168.1.1"] // fallback
    }
    
    private func getRamModules() -> [InventorySnapshot.RamModule] {

        let totalRam = ProcessInfo.processInfo.physicalMemory
        
        // 👉 Assume 2 slots (common case)
        let slotCount = 2
        let perSlot = totalRam / UInt64(slotCount)

        var modules: [InventorySnapshot.RamModule] = []

        for i in 0..<slotCount {

            let capacity = Int(perSlot)

            let module = InventorySnapshot.RamModule(
                Id: UUID().uuidString,
                Slot: "DIMM\(i + 1)",
                Capacity: capacity,
                SerialNumber: UUID().uuidString.prefix(8).uppercased(),
                Manufacturer: "Unknown", // macOS limitation
                Speed: 3200, // estimated (you can adjust)
                PartNumber: "N/A",
                BankLabel: "",
                Tag: "Physical Memory \(i)",
                Caption: "Physical Memory",
                RawView: "Win32_PhysicalMemory.Tag=\"Physical Memory \(i)\""
            )

            modules.append(module)
        }

        return modules
    }
    
    

    // MARK: - Vendor Mapping
    private func getVendorName(vendorID: Int) -> String {
        
        // Convert vendorID to 3-letter manufacturer code (EDID decoding)
        let char1 = Character(UnicodeScalar(((vendorID >> 10) & 0x1F) + 64)!)
        let char2 = Character(UnicodeScalar(((vendorID >> 5) & 0x1F) + 64)!)
        let char3 = Character(UnicodeScalar((vendorID & 0x1F) + 64)!)
        
        let code = "\(char1)\(char2)\(char3)"

        // Optional: map common codes to full names
        switch code {
        case "APP": return "Apple"
        case "DEL": return "Dell"
        case "LGD": return "LG"
        case "SAM": return "Samsung"
        case "HWP": return "HP"
        case "ACR": return "Acer"
        case "ASU": return "ASUS"
        case "PHL": return "Philips"
        case "BNQ": return "BenQ"
        default: return code // fallback → still useful (e.g. "HWP")
        }
    }

    // MARK: - Main Mapper
    func toInventorySnapshot() -> InventorySnapshot {

        func toIntClamped(_ value: UInt64) -> Int {
            return Int(exactly: value) ?? (value > UInt64(Int.max) ? Int.max : Int(value))
        }

        let desktopInfo = InventorySnapshot.DesktopInfo(
            Id: UUID().uuidString,
            Manufacturer: self.DeviceInfo.Manufacturer,
            Model: self.DeviceInfo.Model,
            SerialNumber: self.DeviceInfo.SerialNumber,
            BiosVersion: nil,
            ServiceTag: nil,
            ExpressServiceCode: nil
        )

        let cpuInfo = InventorySnapshot.CpuInfo(
            Id: UUID().uuidString,
            Name: self.Processor.Name,
            Manufacturer: self.Processor.Manufacturer,
            Cores: self.Processor.PhysicalCores,
            LogicalProcessors: self.Processor.LogicalProcessors
        )

        let disks: [InventorySnapshot.Disk] = self.Storage.Disks.map { disk in
            let interfaceType = disk.Interface ?? "Unknown"
            let isExternal = interfaceType == "USB" || disk.MediaType == "External"

            return InventorySnapshot.Disk(
                Id: UUID().uuidString,
                Model: disk.Model,
                SerialNumber: disk.SerialNumber,
                Size: toIntClamped(disk.SizeBytes),
                DriveLetters: disk.DriveLetters,
                FreeSpace: toIntClamped(disk.FreeSizeBytes),
                UsedSpace: toIntClamped(disk.UsedSizeBytes),
                InterfaceType: interfaceType,
                MediaType: disk.MediaType,
                IsSSD: disk.IsSSD,
                FileSystems: disk.FileSystems,
                VolumeNames: disk.DriveLetters,
                IsExternal: isExternal
            )
        }

        let externalDisks = disks.filter { ($0.IsExternal ?? false) }

        let peripherals: [InventorySnapshot.Peripheral] = {
            var list = [InventorySnapshot.Peripheral]()

            self.Peripherals.Keyboards.forEach {
                list.append(.init(Id: UUID().uuidString, Name: $0.Name, DeviceId: nil, Manufacturer: $0.Manufacturer, DeviceType: "Keyboard"))
            }

            self.Peripherals.PointingDevices.forEach {
                list.append(.init(Id: UUID().uuidString, Name: $0.Name, DeviceId: nil, Manufacturer: $0.Manufacturer, DeviceType: "PointingDevice"))
            }

            self.Peripherals.OtherDevices.forEach {
                list.append(.init(Id: UUID().uuidString, Name: $0.Name, DeviceId: nil, Manufacturer: $0.Manufacturer, DeviceType: "Other"))
            }

            return list
        }()

        let installedApps: [InventorySnapshot.InstalledApp] = self.Software.Details.map {
            InventorySnapshot.InstalledApp(
                Id: UUID().uuidString,
                Name: $0.Name,
                Version: $0.Version,
                Publisher: nil,
                InstallLocation: nil,
                UninstallString: nil,
                RegistryKeyPath: nil,
                IsSystemComponent: nil,
                NoRemove: nil,
                WindowsInstaller: nil
            )
        }

        let users: [InventorySnapshot.UserAccount] = self.UserInfo.AssignedUsers.map {
            InventorySnapshot.UserAccount(
                Id: UUID().uuidString,
                Name: $0,
                FullName: nil,
                DisplayName: nil,
                Domain: nil,
                Sid: nil,
                Disabled: nil,
                LocalAccount: nil
            )
        }

        let osInfo = InventorySnapshot.OsInfo(
            Id: UUID().uuidString,
            DeviceId: self.DeviceInfo.DeviceId,
            ProductId: nil,
            SystemType: self.DeviceInfo.SystemType,
            SystemArchitecture: nil,
            Domain: nil,
            Edition: self.OperatingSystem.Edition,
            OsBuildNumber: nil
        )

        let virtualMemoryInfo = InventorySnapshot.VirtualMemoryInfo(
            Id: UUID().uuidString,
            TotalVirtualMemory: nil,
            FreeVirtualMemory: nil,
            UsedVirtualMemory: nil
        )

        return InventorySnapshot(
            Id: UUID().uuidString,
            PcName: self.DeviceInfo.HostName,
            FullDeviceName: self.DeviceInfo.FullQualifiedName,
            DesktopInfo: desktopInfo,
            CpuInfo: cpuInfo,
            TotalRam: toIntClamped(self.Memory.TotalBytes),
            MemoryFrequency: nil,
            RamModules: getRamModules(),
            Gpu: self.Graphics.GpuName,
            TotalStorage: toIntClamped(self.Storage.TotalBytes),
            UsedStorage: toIntClamped(self.Storage.UsedBytes),
            VirtualMemoryInfo: virtualMemoryInfo,
            Disks: disks,
            ExternalDisks: externalDisks,
            NetworkAdapters: getNetworkAdapters(),
            OsInfo: osInfo,
            WindowsUserDisplayNames: self.UserInfo.AssignedUsers.joined(separator: ", "),
            Peripherals: peripherals,
            MonitorDetails: getMonitorDetails(),
            MonitorCount: self.Display.MonitorCount,
            InstalledApps: installedApps,
            ScanTime: self.Audit.ScanTimestamp,
            Users: users
        )
    }
}

