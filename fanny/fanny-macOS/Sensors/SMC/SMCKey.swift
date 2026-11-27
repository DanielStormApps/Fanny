//
//  SMCKey.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

// MARK: - SMCKey
/// A four character SMC key, such as `F0Ac` or `TCMb`, stored as its big endian code.
struct SMCKey: Hashable {
    
    let code: UInt32
    
    static let keyCount: SMCKey = SMCKey(name: "#KEY")
    static let fanCount: SMCKey = SMCKey(name: "FNum")
    
    var name: String {
        let bytes: [UInt8] = [UInt8((code >> 24) & 0xFF),
                              UInt8((code >> 16) & 0xFF),
                              UInt8((code >> 8) & 0xFF),
                              UInt8(code & 0xFF),]
        return String(bytes: bytes, encoding: String.Encoding.ascii) ?? "????"
    }
    
    // MARK: - Init
    init(code: UInt32) {
        self.code = code
    }
    
    /// Only the first four bytes of `name` are used, so a shorter name produces a key the SMC does not have and a longer one is truncated.
    init(name: String) {
        var code: UInt32 = 0
        
        for byte in name.utf8.prefix(4) {
            code = (code << 8) | UInt32(byte)
        }
        
        self.code = code
    }
    
    // MARK: - Fans
    static func fanCurrentSpeed(_ index: Int) -> SMCKey {
        return SMCKey(name: "F\(index)Ac")
    }
    
    static func fanMinimumSpeed(_ index: Int) -> SMCKey {
        return SMCKey(name: "F\(index)Mn")
    }
    
    static func fanMaximumSpeed(_ index: Int) -> SMCKey {
        return SMCKey(name: "F\(index)Mx")
    }
    
    static func fanTargetSpeed(_ index: Int) -> SMCKey {
        return SMCKey(name: "F\(index)Tg")
    }
}

// MARK: - SMCDataType
/// The SMC data types Fanny decodes. Any other type reads as missing.
enum SMCDataType: String {
    case float = "flt "
    case uint8 = "ui8 "
    case uint16 = "ui16"
    case uint32 = "ui32"
    case fpe2 = "fpe2"
    case sp78 = "sp78"
    
    // MARK: - Init
    init?(code: UInt32) {
        self.init(rawValue: SMCKey(code: code).name)
    }
}

// MARK: - SMCKeyInfo
/// The size and data type the SMC reports for a key.
struct SMCKeyInfo: Equatable {
    let dataSize: UInt32
    let dataTypeCode: UInt32
    
    var dataType: SMCDataType? {
        return SMCDataType(code: dataTypeCode)
    }
}

// MARK: - SMCValue
/// The raw bytes of one SMC read, decoded by their data type.
struct SMCValue: Equatable {
    let dataType: SMCDataType?
    let bytes: [UInt8]
    
    /// `nil` for an unknown data type, a payload of the wrong size, or a float that is not finite.
    var doubleValue: Double? {
        let value: Double?
        
        switch dataType {
        case .float:
            value = SMCValue.floatValue(bytes)
        case .uint8:
            value = bytes.count == 1 ? Double(bytes[0]) : nil
        case .uint16:
            value = SMCValue.bigEndianUInt16(bytes).map({ Double($0) })
        case .uint32:
            value = bytes.count == 4 ? Double(SMCValue.bigEndianUInt32(bytes)) : nil
        case .fpe2:
            value = SMCValue.bigEndianUInt16(bytes).map({ Double($0) / 4.0 })
        case .sp78:
            value = SMCValue.bigEndianUInt16(bytes).map({ Double(Int16(bitPattern: $0)) / 256.0 })
        case .none:
            value = nil
        }
        
        return value
    }
    
    // MARK: - Decoding
    /// Apple silicon stores `flt ` values as little endian Float32.
    private static func floatValue(_ bytes: [UInt8]) -> Double? {
        guard bytes.count == 4 else { return nil }
        
        let bitPattern: UInt32 = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        let value: Double = Double(Float(bitPattern: bitPattern))
        return value.isFinite ? value : nil
    }
    
    private static func bigEndianUInt16(_ bytes: [UInt8]) -> UInt16? {
        guard bytes.count == 2 else { return nil }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }
    
    private static func bigEndianUInt32(_ bytes: [UInt8]) -> UInt32 {
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }
}
