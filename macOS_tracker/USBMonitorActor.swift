//
//  USBMonitorActor.swift
//  macOS_tracker
//
//  Created by Saumil on 10/04/26.
//

import Foundation

actor USBMonitorActor {

    static let shared = USBMonitorActor()

    private var seenDevices: Set<USBDevice> = []

    // MARK: - Add Device
    func addDevice(_ device: USBDevice) -> Bool {
        if !seenDevices.contains(device) {
            seenDevices.insert(device)
            return true
        }
        return false
    }

    // MARK: - Remove Device
    func removeDevice(vendor: Int, product: Int) -> USBDevice? {
        if let existing = seenDevices.first(where: {
            $0.vendorId == vendor && $0.productId == product
        }) {
            seenDevices.remove(existing)
            return existing
        }
        return nil
    }

    // MARK: - Get Snapshot   
    func getDevices() -> Set<USBDevice> {
        return seenDevices
    }
}
