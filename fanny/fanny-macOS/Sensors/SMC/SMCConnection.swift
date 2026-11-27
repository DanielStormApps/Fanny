//
//  SMCConnection.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import IOKit

// MARK: - SMCParamStruct
typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

/// The version block of the SMC call struct.
struct SMCParamVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

/// The power limit block of the SMC call struct.
struct SMCParamPowerLimit {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPowerLimit: UInt32 = 0
    var gpuPowerLimit: UInt32 = 0
    var memoryPowerLimit: UInt32 = 0
}

/// The key info block of the SMC call struct.
struct SMCParamKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

/// The 80 byte struct the `AppleSMC` user client takes and returns.
/// - Note: `padding` stands in for the C struct's trailing padding after `keyInfo`, so `result` lands at offset 40 like the kernel expects.
struct SMCParamStruct {
    var key: UInt32 = 0
    var version: SMCParamVersion = SMCParamVersion()
    var powerLimit: SMCParamPowerLimit = SMCParamPowerLimit()
    var keyInfo: SMCParamKeyInfo = SMCParamKeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

// MARK: - SMCConnectionError
/// Why the `AppleSMC` connection could not open.
enum SMCConnectionError: Error {
    case serviceNotFound
    case openFailed(result: kern_return_t)
}

// MARK: - SMCKeyLookup
/// The answer to a key info call, which tells a key the Mac does not have apart from a call that failed.
enum SMCKeyLookup {
    case found(SMCKeyInfo)
    case notFound
    case failed
}

// MARK: - SMCConnection
/// One open connection to the `AppleSMC` service, used from a single queue.
final class SMCConnection {
    
    private let connection: io_connect_t
    
    private static let serviceName: String = "AppleSMC"
    private static let kernelIndex: UInt32 = 2
    private static let readBytesCommand: UInt8 = 5
    private static let readIndexCommand: UInt8 = 8
    private static let readKeyInfoCommand: UInt8 = 9
    private static let successResult: UInt8 = 0
    private static let keyNotFoundResult: UInt8 = 0x84
    
    // MARK: - Init
    init() throws {
        let service: io_service_t = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(SMCConnection.serviceName))
        guard service != IO_OBJECT_NULL else { throw SMCConnectionError.serviceNotFound }
        defer { IOObjectRelease(service) }
        
        var openedConnection: io_connect_t = IO_OBJECT_NULL
        let result: kern_return_t = IOServiceOpen(service, mach_task_self_, 0, &openedConnection)
        guard result == kIOReturnSuccess else { throw SMCConnectionError.openFailed(result: result) }
        connection = openedConnection
    }
    
    deinit {
        IOServiceClose(connection)
    }
    
    // MARK: - Reading
    /// - Returns: `notFound` when the Mac does not have the key (result `0x84`).
    func keyInfo(_ key: SMCKey) -> SMCKeyLookup {
        var input: SMCParamStruct = SMCParamStruct()
        input.key = key.code
        input.data8 = SMCConnection.readKeyInfoCommand
        
        guard let output: SMCParamStruct = call(&input) else { return SMCKeyLookup.failed }
        let lookup: SMCKeyLookup
        
        switch output.result {
        case SMCConnection.successResult:
            lookup = SMCKeyLookup.found(SMCKeyInfo(dataSize: output.keyInfo.dataSize, dataTypeCode: output.keyInfo.dataType))
        case SMCConnection.keyNotFoundResult:
            lookup = SMCKeyLookup.notFound
        default:
            lookup = SMCKeyLookup.failed
        }
        
        return lookup
    }
    
    private func readBytes(_ key: SMCKey, info: SMCKeyInfo) -> [UInt8]? {
        var input: SMCParamStruct = SMCParamStruct()
        input.key = key.code
        input.keyInfo.dataSize = info.dataSize
        input.data8 = SMCConnection.readBytesCommand
        
        guard
            let output: SMCParamStruct = call(&input),
            output.result == SMCConnection.successResult
        else { return nil }
        
        let byteCount: Int = min(Int(info.dataSize), MemoryLayout<SMCBytes>.size)
        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(byteCount)) }
    }
    
    /// The key at a position in the SMC's key list, from 0 to the `#KEY` count.
    func key(at index: UInt32) -> SMCKey? {
        var input: SMCParamStruct = SMCParamStruct()
        input.data8 = SMCConnection.readIndexCommand
        input.data32 = index
        
        guard
            let output: SMCParamStruct = call(&input),
            output.result == SMCConnection.successResult
        else { return nil }
        
        return SMCKey(code: output.key)
    }
    
    func value(_ key: SMCKey, info: SMCKeyInfo) -> SMCValue? {
        guard let bytes: [UInt8] = readBytes(key, info: info) else { return nil }
        return SMCValue(dataType: info.dataType, bytes: bytes)
    }
    
    // MARK: - Helpers
    /// - Returns: `nil` when the kernel call fails. The caller checks the SMC's own `result`.
    private func call(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        var output: SMCParamStruct = SMCParamStruct()
        var outputSize: Int = MemoryLayout<SMCParamStruct>.stride
        let result: kern_return_t = IOConnectCallStructMethod(connection, SMCConnection.kernelIndex, &input, MemoryLayout<SMCParamStruct>.stride, &output, &outputSize)
        
        guard result == kIOReturnSuccess else { return nil }
        return output
    }
}
