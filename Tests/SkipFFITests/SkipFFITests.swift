// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org
import XCTest
#if !SKIP
import SQLite3
#endif

@available(macOS 13, *)
final class SkipFFITests: XCTestCase {
    func testSimpleDarwinJNA() throws {
        XCTAssertEqual(12, Darwin.abs(-12))
        Darwin.free(Darwin.malloc(8))

        XCTAssertNotNil(Darwin.getenv("PATH"), "PATH environent should be set for getenv")
        XCTAssertNil(Darwin.getenv("PATH_DOES_NOT_EXIST"), "non-existent key should not return a value for getenv")
    }

    func testSQLiteJNA() throws {
        /// Whether we are on an Android OS (emulator or device), versus the Robolectric environment
        let isAndroid = Darwin.getenv("ANDROID_ROOT") != nil

        if isAndroid {
            throw XCTSkip("Error loading on Android: java.lang.UnsatisfiedLinkError: Unable to load library 'sqlite3': dlopen failed: library \"libsqlite3.so\" not found")
        } else {
            XCTAssertEqual(0, SQLite3.sqlite3_sleep(0))
        }

//        #if SKIP
//        var db: OpaquePointer?
//
//        XCTAssertEqual(0, SQLite3.sqlite3_open_v2(":memory", db, SQLite3.SQLITE_OPEN_CREATE | SQLite3.SQLITE_OPEN_READWRITE, nil))
//        #else
//        var db: OpaquePointer?
//        XCTAssertEqual(0, SQLite3.sqlite3_open_v2(":memory", &db, SQLite3.SQLITE_OPEN_CREATE | SQLite3.SQLITE_OPEN_READWRITE, nil))
//        #endif

//        XCTAssertEqual(0, SQLite3.sqlite3_close_v2(db))
//        XCTAssertEqual(21, SQLite3.sqlite3_close_v2(db), "expected error code for double-close")
    }
}

#if SKIP
import com.sun.jna.__
import com.sun.jna.ptr.__

/// A bridge from Darwin functions to Android's Bionic libc.
let Darwin: BionicDarwin = Native.load("c", (BionicDarwin.self as kotlin.reflect.KClass).java)

typealias OpaquePointer = PointerByReference

protocol BionicDarwin : Library {
    func abs(_ value: Int) -> Int

    func malloc(_ size: Int) -> OpaquePointer
    func free(_ ptr: OpaquePointer) -> Int

    func getenv(_ key: String) -> String?
}

/// Direct access to the Android SQLite library from Skip.
let SQLite3: SQLiteLibrary = Native.load("sqlite3", (SQLiteLibrary.self as kotlin.reflect.KClass).java)

protocol SQLiteLibrary : Library {

    func sqlite3_sleep(_ duration: Int32) -> Int32
    func sqlite3_open_v2(_ filename: String, _ ppDb: OpaquePointer?, _ flags: Int32, _ zVfs: OpaquePointer?) -> Int32

    //public func sqlite3_open_v2(_ filename: UnsafePointer<CChar>!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!, _ flags: Int32, _ zVfs: UnsafePointer<CChar>!) -> Int32

}

extension SQLiteLibrary {
    var SQLITE_OPEN_READWRITE: Int32 { 2 }
    var SQLITE_OPEN_CREATE: Int32 { 4 }
}

#endif
