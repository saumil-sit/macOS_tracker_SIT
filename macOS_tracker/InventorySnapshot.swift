import Foundation

/// Top-level model matching the provided inventory JSON schema.
public struct InventorySnapshot: Codable {
    public let Id: String?
    public let PcName: String?
    public let FullDeviceName: String?
    public let DesktopInfo: DesktopInfo?
    public let CpuInfo: CpuInfo?
    public let TotalRam: Int?
    public let MemoryFrequency: String?
    public let RamModules: [RamModule]?
    public let Gpu: String?
    public let TotalStorage: Int?
    public let UsedStorage: Int?
    public let VirtualMemoryInfo: VirtualMemoryInfo?
    public let Disks: [Disk]?
    public let ExternalDisks: [Disk]?
    public let NetworkAdapters: [NetworkAdapter]?
    public let OsInfo: OsInfo?
    public let WindowsUserDisplayNames: String?
    public let Peripherals: [Peripheral]?
    public let MonitorDetails: [MonitorDetail]?
    public let MonitorCount: Int?
    public let InstalledApps: [InstalledApp]?
    public let ScanTime: String?
    public let Users: [UserAccount]?

    public init(
        Id: String? = nil,
        PcName: String? = nil,
        FullDeviceName: String? = nil,
        DesktopInfo: DesktopInfo? = nil,
        CpuInfo: CpuInfo? = nil,
        TotalRam: Int? = nil,
        MemoryFrequency: String? = nil,
        RamModules: [RamModule]? = nil,
        Gpu: String? = nil,
        TotalStorage: Int? = nil,
        UsedStorage: Int? = nil,
        VirtualMemoryInfo: VirtualMemoryInfo? = nil,
        Disks: [Disk]? = nil,
        ExternalDisks: [Disk]? = nil,
        NetworkAdapters: [NetworkAdapter]? = nil,
        OsInfo: OsInfo? = nil,
        WindowsUserDisplayNames: String? = nil,
        Peripherals: [Peripheral]? = nil,
        MonitorDetails: [MonitorDetail]? = nil,
        MonitorCount: Int? = nil,
        InstalledApps: [InstalledApp]? = nil,
        ScanTime: String? = nil,
        Users: [UserAccount]? = nil
    ) {
        self.Id = Id
        self.PcName = PcName
        self.FullDeviceName = FullDeviceName
        self.DesktopInfo = DesktopInfo
        self.CpuInfo = CpuInfo
        self.TotalRam = TotalRam
        self.MemoryFrequency = MemoryFrequency
        self.RamModules = RamModules
        self.Gpu = Gpu
        self.TotalStorage = TotalStorage
        self.UsedStorage = UsedStorage
        self.VirtualMemoryInfo = VirtualMemoryInfo
        self.Disks = Disks
        self.ExternalDisks = ExternalDisks
        self.NetworkAdapters = NetworkAdapters
        self.OsInfo = OsInfo
        self.WindowsUserDisplayNames = WindowsUserDisplayNames
        self.Peripherals = Peripherals
        self.MonitorDetails = MonitorDetails
        self.MonitorCount = MonitorCount
        self.InstalledApps = InstalledApps
        self.ScanTime = ScanTime
        self.Users = Users
    }

    private enum CodingKeys: String, CodingKey {
        case Id, PcName, FullDeviceName, DesktopInfo, CpuInfo, TotalRam, MemoryFrequency, RamModules, Gpu, TotalStorage, UsedStorage, VirtualMemoryInfo, Disks, ExternalDisks, NetworkAdapters, OsInfo, WindowsUserDisplayNames, Peripherals, MonitorDetails, MonitorCount, InstalledApps, ScanTime, Users
    }
}

// MARK: - Nested Types

public extension InventorySnapshot {
    /// Information about the desktop device.
    struct DesktopInfo: Codable {
        public let Id: String?
        public let Manufacturer: String?
        public let Model: String?
        public let SerialNumber: String?
        public let BiosVersion: String?
        public let ServiceTag: String?
        public let ExpressServiceCode: String?

        private enum CodingKeys: String, CodingKey {
            case Id, Manufacturer, Model, SerialNumber, BiosVersion, ServiceTag, ExpressServiceCode
        }
    }

    /// CPU details.
    struct CpuInfo: Codable {
        public let Id: String?
        public let Name: String?
        public let Manufacturer: String?
        public let Cores: Int?
        public let LogicalProcessors: Int?

        private enum CodingKeys: String, CodingKey {
            case Id, Name, Manufacturer, Cores, LogicalProcessors
        }
    }

    /// Details about a RAM module.
    struct RamModule: Codable {
        public let Id: String?
        public let Slot: String?
        public let Capacity: Int?
        public let SerialNumber: String?
        public let Manufacturer: String?
        public let Speed: Int?
        public let PartNumber: String?
        public let BankLabel: String?
        public let Tag: String?
        public let Caption: String?
        public let RawView: String?

        private enum CodingKeys: String, CodingKey {
            case Id, Slot, Capacity, SerialNumber, Manufacturer, Speed, PartNumber, BankLabel, Tag, Caption, RawView
        }
    }

    /// Virtual memory information.
    struct VirtualMemoryInfo: Codable {
        public let Id: String?
        public let TotalVirtualMemory: Int?
        public let FreeVirtualMemory: Int?
        public let UsedVirtualMemory: Int?

        private enum CodingKeys: String, CodingKey {
            case Id, TotalVirtualMemory, FreeVirtualMemory, UsedVirtualMemory
        }
    }

    /// Disk drive details.
    struct Disk: Codable {
        public let Id: String?
        public let Model: String?
        public let SerialNumber: String?
        public let Size: Int?
        public let DriveLetters: [String]?
        public let FreeSpace: Int?
        public let UsedSpace: Int?
        public let InterfaceType: String?
        public let MediaType: String?
        public let IsSSD: Bool?
        public let FileSystems: [String]?
        public let VolumeNames: [String]?
        public let IsExternal: Bool?

        private enum CodingKeys: String, CodingKey {
            case Id, Model, SerialNumber, Size, DriveLetters, FreeSpace, UsedSpace, InterfaceType, MediaType, IsSSD, FileSystems, VolumeNames, IsExternal
        }
    }

    /// Network adapter details.
    struct NetworkAdapter: Codable {
        public let Id: String?
        public let Name: String?
        public let Description: String?
        public let NetworkId: String?
        public let MacAddress: String?
        public let InterfaceType: String?
        public let Status: String?
        public let IsUp: Bool?
        public let Speed: Int?
        public let SupportsMulticast: Bool?
        public let DhcpEnabled: Bool?
        public let DnsSuffix: String?
        public let IpAddresses: [String]?
        public let GatewayAddresses: [String]?
        public let DnsAddresses: [String]?
        public let DhcpServers: [String]?

        private enum CodingKeys: String, CodingKey {
            case Id, Name, Description, NetworkId, MacAddress, InterfaceType, Status, IsUp, Speed, SupportsMulticast, DhcpEnabled, DnsSuffix, IpAddresses, GatewayAddresses, DnsAddresses, DhcpServers
        }
    }

    /// Operating system information.
    struct OsInfo: Codable {
        public let Id: String?
        public let DeviceId: String?
        public let ProductId: String?
        public let SystemType: String?
        public let SystemArchitecture: String?
        public let Domain: String?
        public let Edition: String?
        public let OsBuildNumber: String?

        private enum CodingKeys: String, CodingKey {
            case Id, DeviceId, ProductId, SystemType, SystemArchitecture, Domain, Edition, OsBuildNumber
        }
    }

    /// Peripheral device details.
    struct Peripheral: Codable {
        public let Id: String?
        public let Name: String?
        public let DeviceId: String?
        public let Manufacturer: String?
        public let DeviceType: String?

        private enum CodingKeys: String, CodingKey {
            case Id, Name, DeviceId, Manufacturer
            case DeviceType = "Type"
        }
    }

    /// Monitor details.
    struct MonitorDetail: Codable {
        public let Id: String?
        public let Manufacturer: String?
        public let ProductName: String?
        public let SerialNumber: String?
        public let InstanceName: String?
        public let RawManufacturer: String?
        public let RawProduct: String?
        public let RawSerial: String?

        private enum CodingKeys: String, CodingKey {
            case Id, Manufacturer, ProductName, SerialNumber, InstanceName, RawManufacturer, RawProduct, RawSerial
        }
    }

    /// Installed application details.
    struct InstalledApp: Codable {
        public let Id: String?
        public let Name: String?
        public let Version: String?
        public let Publisher: String?
        public let InstallLocation: String?
        public let UninstallString: String?
        public let RegistryKeyPath: String?
        public let IsSystemComponent: Bool?
        public let NoRemove: Bool?
        public let WindowsInstaller: Bool?

        private enum CodingKeys: String, CodingKey {
            case Id, Name, Version, Publisher, InstallLocation, UninstallString, RegistryKeyPath, IsSystemComponent, NoRemove, WindowsInstaller
        }
    }

    /// User account information.
    struct UserAccount: Codable {
        public let Id: String?
        public let Name: String?
        public let FullName: String?
        public let DisplayName: String?
        public let Domain: String?
        public let Sid: String?
        public let Disabled: Bool?
        public let LocalAccount: Bool?

        private enum CodingKeys: String, CodingKey {
            case Id, Name, FullName, DisplayName, Domain, Sid, Disabled, LocalAccount
        }
    }
}

// MARK: - Convenience

public extension InventorySnapshot {
    /// Decodes an InventorySnapshot from given JSON data.
    static func decode(from data: Data) throws -> InventorySnapshot {
        let decoder = JSONDecoder()
        return try decoder.decode(InventorySnapshot.self, from: data)
    }

    /// Encodes an InventorySnapshot to JSON data.
    static func encode(_ snapshot: InventorySnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}

