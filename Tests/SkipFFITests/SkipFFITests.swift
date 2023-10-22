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
        #if SKIP
        // You may set the system property jna.debug_load=true to make JNA print the steps of its library search to the console.
        // https://java-native-access.github.io/jna/4.2.1/com/sun/jna/NativeLibrary.html#library_search_paths
        System.setProperty("jna.debug_load", "true")

        /// A fake "Darwin" namespace atop Android's Bionic libc via JNA FFI
        let Darwin: BionicDarwin = com.sun.jna.Native.load("c", (BionicDarwin.self as kotlin.reflect.KClass).java)
        //let Darwin: BionicDarwin = loadLibrary("c")
        #endif

        XCTAssertEqual(12, Darwin.abs(-12))
        Darwin.free(Darwin.malloc(8))

        XCTAssertNotNil(Darwin.getenv("PATH"), "PATH environent should be set for getenv")
        XCTAssertNil(Darwin.getenv("PATH_DOES_NOT_EXIST"), "non-existent key should not return a value for getenv")
    }

    func testSQLiteJNA() throws {
        #if SKIP
        // You may set the system property jna.debug_load=true to make JNA print the steps of its library search to the console.
        // https://java-native-access.github.io/jna/4.2.1/com/sun/jna/NativeLibrary.html#library_search_paths
        System.setProperty("jna.debug_load", "true")

        /// A fake "Darwin" namespace atop Android's Bionic libc via JNA FFI
        let Darwin: BionicDarwin = com.sun.jna.Native.load("c", (BionicDarwin.self as kotlin.reflect.KClass).java)

        /// Direct access to the Android SQLite library from Skip.
        let SQLite3: SQLiteLibrary = {
            do {
                return com.sun.jna.Native.load("sqlite3", (SQLiteLibrary.self as kotlin.reflect.KClass).java)
            } catch let error as java.lang.UnsatisfiedLinkError { // "Unable to load library 'sqlite3'"
                // on Android the sqlite3 lib is already loaded, so we can map to the current process for symbols
                // http://java-native-access.github.io/jna/5.13.0/javadoc/com/sun/jna/Native.html#load-java.lang.String-java.lang.Class-
                return com.sun.jna.Native.load(nil, (SQLiteLibrary.self as kotlin.reflect.KClass).java)
            }
        }()
        #endif


        /// Whether we are on an Android OS (emulator or device), versus the Robolectric environment
        let isAndroid = Darwin.getenv("ANDROID_ROOT") != nil

        if isAndroid {
            // TODO: figure out how to load the sqlite library on Android
            // possibly related: https://github.com/simolus3/drift/issues/895#issuecomment-729165464
            throw XCTSkip("Error loading on Android: java.lang.UnsatisfiedLinkError: Unable to load library 'sqlite3': dlopen failed: library \"libsqlite3.so\" not found")
        }

        XCTAssertEqual(0, SQLite3.sqlite3_sleep(0))

        var db: OpaquePointer? = nil
        //let s1 = SQLite3.sqlite3_open(":memory:", &db)
        let s1 = withUnsafeMutablePointer(to: &db) { ptr in
            SQLite3.sqlite3_open(":memory:", ptr)
        }
        XCTAssertNotNil(db)
        XCTAssertEqual(0, s1)

        func check(sql: String, code: Int32 = 0) {
            let statusCode = SQLite3.sqlite3_exec(db, sql, nil, nil, nil)
            XCTAssertEqual(code, statusCode)
        }

        check(sql: "SELECT 1")
        check(sql: "SELECT CURRENT_TIMESTAMP")

        check(sql: "CREATE TABLE FOO(ID INT)")
        check(sql: "CREATE TABLE FOO(ID INT)", code: 1)

        check(sql: "DROP TABLE FOO")
        check(sql: "DROP TABLE FOO", code: 1)

        // check errors codes
        check(sql: "SELECT UNKNOWN_COLUMN", code: 1)
        check(sql: "ILLEGAL_SQL", code: 1)

        let s2 = SQLite3.sqlite3_close(db)
        XCTAssertEqual(0, s2)

        let s3 = SQLite3.sqlite3_close(db)
        XCTAssertEqual(21, s3, "double-close should return an invalid handle error status")
    }
}

#if SKIP

// MARK: BionicDarwin

protocol BionicDarwin : com.sun.jna.Library {
    func abs(_ value: Int32) -> Int32

    func malloc(_ size: Int32) -> OpaquePointer
    func free(_ ptr: OpaquePointer) -> Int32

    func getenv(_ key: String) -> String?
}


// MARK: SQLiteLibrary

protocol SQLiteLibrary : com.sun.jna.Library {
    func sqlite3_open(_ filename: String, _ ppDb: com.sun.jna.ptr.PointerByReference?) -> Int32
    func sqlite3_close(_ ppDb: com.sun.jna.Pointer?) -> Int32

    func sqlite3_exec(_ ppDb: com.sun.jna.Pointer?, _ sql: String, _ callback: com.sun.jna.Pointer?, _ columns: com.sun.jna.Pointer?, _ errmsg: com.sun.jna.Pointer?) -> Int32

    func sqlite3_sleep(_ duration: Int32) -> Int32
}

extension SQLiteLibrary {
    var SQLITE_OPEN_READWRITE: Int32 { 2 }
    var SQLITE_OPEN_CREATE: Int32 { 4 }
}

#endif
