// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org
import XCTest
import Foundation

@available(macOS 13, *)
final class SkipFFITests: XCTestCase {
    func testSkipFFI() throws {
        XCTAssertEqual(12, Darwin.abs(-12))
        Darwin.free(Darwin.malloc(8))
    }
}

#if SKIP
import com.sun.jna.__
import com.sun.jna.ptr.__

/// A bridge from Darwin functions to Android's Bionic libc.
let Darwin: BionicCompatLibrary = {
    Native.load("c", (BionicCompatLibrary.self as kotlin.reflect.KClass).java)
}()

protocol BionicCompatLibrary : Library {
    func abs(_ value: Int) -> Int

    func malloc(_ size: Int) -> PointerByReference
    func free(_ ptr: PointerByReference) -> Int
}
#endif
