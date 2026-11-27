//
//  SMCValueTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests SMC key codes, value decoding for each data type, and the call struct layout.
final class SMCValueTests: XCTestCase {
    
    func testKeyNameRoundTripsThroughItsCode() {
        let key: SMCKey = SMCKey(name: "TCMb")
        XCTAssertEqual(key.code, 0x54434D62)
        XCTAssertEqual(key.name, "TCMb")
        XCTAssertEqual(SMCKey(code: key.code), key)
        XCTAssertEqual(SMCKey.fanCurrentSpeed(1).name, "F1Ac")
        XCTAssertEqual(SMCKey.fanMinimumSpeed(0).name, "F0Mn")
        XCTAssertEqual(SMCKey.fanMaximumSpeed(0).name, "F0Mx")
        XCTAssertEqual(SMCKey.fanTargetSpeed(0).name, "F0Tg")
        XCTAssertEqual(SMCKey.keyCount.name, "#KEY")
    }
    
    func testDataTypeDecodesFromItsCode() {
        XCTAssertEqual(SMCDataType(code: SMCKey(name: "flt ").code), SMCDataType.float)
        XCTAssertEqual(SMCDataType(code: SMCKey(name: "ui8 ").code), SMCDataType.uint8)
        XCTAssertEqual(SMCDataType(code: SMCKey(name: "sp78").code), SMCDataType.sp78)
        XCTAssertNil(SMCDataType(code: SMCKey(name: "ch8*").code))
    }
    
    func testFloatIsLittleEndian() {
        // F0Mx on an M4 reads `00 20 99 45`, which is 4900 RPM.
        XCTAssertEqual(SMCValue(dataType: .float, bytes: [0x00, 0x20, 0x99, 0x45]).doubleValue, 4900.0)
        XCTAssertEqual(SMCValue(dataType: .float, bytes: [0x00, 0x00, 0x20, 0x42]).doubleValue, 40.0)
        XCTAssertEqual(SMCValue(dataType: .float, bytes: [0x00, 0x00, 0x00, 0x00]).doubleValue, 0.0)
    }
    
    func testFloatRejectsWrongSizeAndNonFiniteValues() {
        XCTAssertNil(SMCValue(dataType: .float, bytes: [0x00, 0x20, 0x99]).doubleValue)
        XCTAssertNil(SMCValue(dataType: .float, bytes: [0x00, 0x00, 0xC0, 0x7F]).doubleValue)
        XCTAssertNil(SMCValue(dataType: .float, bytes: [0x00, 0x00, 0x80, 0x7F]).doubleValue)
    }
    
    func testUnsignedIntegersAreBigEndian() {
        XCTAssertEqual(SMCValue(dataType: .uint8, bytes: [0x02]).doubleValue, 2.0)
        XCTAssertEqual(SMCValue(dataType: .uint16, bytes: [0x01, 0x02]).doubleValue, 258.0)
        XCTAssertEqual(SMCValue(dataType: .uint32, bytes: [0x00, 0x00, 0x09, 0xEB]).doubleValue, 2539.0)
        XCTAssertNil(SMCValue(dataType: .uint8, bytes: []).doubleValue)
        XCTAssertNil(SMCValue(dataType: .uint16, bytes: [0x01]).doubleValue)
        XCTAssertNil(SMCValue(dataType: .uint32, bytes: [0x01, 0x02]).doubleValue)
    }
    
    func testFixedPointTypes() {
        // fpe2 keeps two fraction bits: 0x1518 / 4 = 1350.
        XCTAssertEqual(SMCValue(dataType: .fpe2, bytes: [0x15, 0x18]).doubleValue, 1350.0)
        // sp78 is signed with eight fraction bits.
        XCTAssertEqual(SMCValue(dataType: .sp78, bytes: [0x2D, 0x80]).doubleValue, 45.5)
        XCTAssertEqual(SMCValue(dataType: .sp78, bytes: [0xFF, 0x00]).doubleValue, -1.0)
        XCTAssertNil(SMCValue(dataType: .sp78, bytes: [0x2D]).doubleValue)
    }
    
    func testUnknownDataTypeReadsAsMissing() {
        XCTAssertNil(SMCValue(dataType: nil, bytes: [0x01, 0x02, 0x03, 0x04]).doubleValue)
    }
    
    func testParamStructMatchesTheKernelLayout() {
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.stride, 80)
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.keyInfo), 28)
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.result), 40)
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.data8), 42)
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.data32), 44)
        XCTAssertEqual(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.bytes), 48)
    }
}
