// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
import XCTest
import Foundation
import SkipFFI

#if !SKIP
#if canImport(SQLite3)
import SQLite3
#endif
#else
private lazy let SQLite3 = SQLiteLibrary()
#endif

#if !SKIP
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#else
private lazy let Darwin = BionicDarwin()
#endif

#if !SKIP
#if canImport(zlib)
import zlib
#endif
#else
private lazy let zlib = ZlibLibrary()
#endif

#if !SKIP
#if canImport(libxml2)
import libxml2
#endif
#else
private lazy let libxml2 = LibXMLLibrary()
#endif

@available(macOS 13, *)
final class SkipFFITests: XCTestCase {
    func testSimpleDarwinJNA() throws {
        // You may set the system property jna.debug_load=true to make JNA print the steps of its library search to the console.
        // https://java-native-access.github.io/jna/4.2.1/com/sun/jna/NativeLibrary.html#library_search_paths
        //System.setProperty("jna.debug_load", "true")

        #if canImport(Glibc)
        XCTAssertEqual(12, Glibc.abs(-12))
        Glibc.free(Glibc.malloc(8))

        XCTAssertNotNil(Glibc.getenv("PATH"), "PATH environment should be set for getenv")
        XCTAssertNil(Glibc.getenv("PATH_DOES_NOT_EXIST"), "non-existent key should not return a value for getenv")
        #else
        XCTAssertEqual(12, Darwin.abs(-12))
        Darwin.free(Darwin.malloc(8))

        XCTAssertNotNil(Darwin.getenv("PATH"), "PATH environment should be set for getenv")
        XCTAssertNil(Darwin.getenv("PATH_DOES_NOT_EXIST"), "non-existent key should not return a value for getenv")
        #endif
    }   

    func testJNAPlatform() throws {
        #if SKIP
        XCTAssertEqual(isAndroid, com.sun.jna.Platform.isAndroid())
        //XCTAssertEqual(isMacOS, com.sun.jna.Platform.isMac())
        #endif
    }

    func testDataWithUnsafeBytes() throws {
        let data = "ABC".data(using: String.Encoding.utf8)!
        let baseAddress = data.withUnsafeBytes {
            $0.baseAddress
        }
        XCTAssertNotNil(baseAddress)
    }

    /// Mutating the bytes through the pointer must be reflected back in the `Data`
    /// on both platforms (regression test for the write-back being dropped on Android).
    func testDataWithUnsafeMutableBytesWritesBack() throws {
        var data = "ABC".data(using: String.Encoding.utf8)!
        data.withUnsafeMutableBytes { rawBuffer in
            #if SKIP
            // write the replacement bytes into the native buffer through the pointer
            let replacement = "XYZ".data(using: String.Encoding.utf8)!.kotlin(nocopy: true)
            rawBuffer.baseAddress.write(0, replacement, 0, 3)
            #else
            rawBuffer.copyBytes(from: Array("XYZ".utf8))
            #endif
        }
        XCTAssertEqual(data, "XYZ".data(using: String.Encoding.utf8)!)
    }

    /// `withFFIDataPointer` should return the bytes written into the buffer by the block.
    func testWithFFIDataPointerFill() throws {
        let result = withFFIDataPointer(size: 3) { ptr in
            #if SKIP
            let bytes = "XYZ".data(using: String.Encoding.utf8)!.kotlin(nocopy: true)
            ptr.write(0, bytes, 0, 3)
            #else
            let dst = ptr.assumingMemoryBound(to: UInt8.self)
            let src = Array("XYZ".utf8)
            for i in 0..<3 { dst[i] = src[i] }
            #endif
            return Int32(3)
        }
        XCTAssertEqual(result, "XYZ".data(using: String.Encoding.utf8)!)
    }

    /// A block that returns a negative count (the conventional C error signal) should
    /// yield `nil` rather than trapping or throwing an opaque array exception.
    func testWithFFIDataPointerNegativeCountReturnsNil() throws {
        let result = withFFIDataPointer(size: 8) { _ in
            return Int32(-1)
        }
        XCTAssertNil(result)
    }

    /// Reading the bytes back through `baseAddress` must yield the original contents
    /// (the existing `testDataWithUnsafeBytes` only checks that the pointer is non-nil).
    func testDataWithUnsafeBytesReadsContents() throws {
        let data = "ABC".data(using: String.Encoding.utf8)!
        let readBack: Data = data.withUnsafeBytes { raw in
            #if SKIP
            return Data(platformValue: raw.baseAddress.getByteArray(0, 3))
            #else
            return Data(bytes: raw.baseAddress!, count: 3)
            #endif
        }
        XCTAssertEqual(readBack, data)
    }

    /// `withFFIStringPointer` should return the NUL-terminated string written by the block.
    /// With the default `clear: true` the buffer is zeroed first, so writing the bytes
    /// without an explicit terminator still yields the correct string.
    func testWithFFIStringPointer() throws {
        let result = withFFIStringPointer(size: 5) { ptr in
            #if SKIP
            let bytes = "HELLO".data(using: String.Encoding.utf8)!.kotlin(nocopy: true)
            ptr.write(0, bytes, 0, 5)
            #else
            let src = Array("HELLO".utf8)
            for i in 0..<5 { ptr[i] = CChar(bitPattern: src[i]) }
            #endif
        }
        XCTAssertEqual(result, "HELLO")
    }

    /// With `clear: false` the block is responsible for the NUL terminator; the returned
    /// string must still stop at it.
    func testWithFFIStringPointerNoClear() throws {
        let result = withFFIStringPointer(size: 5, clear: false) { ptr in
            #if SKIP
            // write "HELLO" followed by an explicit NUL terminator (6 bytes)
            let bytes = kotlin.ByteArray(6)
            let hello = "HELLO".data(using: String.Encoding.utf8)!.kotlin(nocopy: true)
            for i in 0..<5 { bytes[i] = hello[i] }
            ptr.write(0, bytes, 0, 6)
            #else
            let src = Array("HELLO".utf8)
            for i in 0..<5 { ptr[i] = CChar(bitPattern: src[i]) }
            ptr[5] = CChar(0)
            #endif
        }
        XCTAssertEqual(result, "HELLO")
    }

    /// When the block fills fewer than `size` bytes per call, `withFFIDataPointer` must
    /// keep reading the remaining bytes until the full size is assembled. Here each call
    /// writes a single byte, so reaching `size` requires multiple reads.
    func testWithFFIDataPointerMultiRead() throws {
        let result = withFFIDataPointer(size: 3) { ptr in
            #if SKIP
            ptr.setByte(0, Int8(65)) // 'A'
            #else
            ptr.assumingMemoryBound(to: UInt8.self)[0] = UInt8(65) // 'A'
            #endif
            return Int32(1)
        }
        XCTAssertEqual(result, "AAA".data(using: String.Encoding.utf8)!)
    }

    func testDarwinDirectMappingJNA() throws {
        let dd = DarwinDirect()
        XCTAssertEqual(12, dd.abs(-12))
    }

    #if SKIP || os(macOS) // i.e., not Linux
    func testSQLiteJNA() throws {
        #if SKIP
        // You may set the system property jna.debug_load=true to make JNA print the steps of its library search to the console.
        // https://java-native-access.github.io/jna/4.2.1/com/sun/jna/NativeLibrary.html#library_search_paths
        System.setProperty("jna.debug_load", "true")
        #endif

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

        check(sql: "PRAGMA compile_options")

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

    func testZLibJNA() throws {
        let stream = z_stream() // note that we must *not* use zlib.z_stream
        XCTAssertEqual(stream.avail_out, 0)

        let zlibVersion = String(cString: zlib.zlibVersion())

        // 1.2.11 for Android and macOS 13, 1.2.12 for more recent versions
        // Ubuntu 24.04 has zlib 1.3
        // so just assume it is something that starts with "1."
        XCTAssertTrue(zlibVersion.hasPrefix("1."), "unexpected zlib version: \(zlibVersion)")
    }

    /// Note that libxml2 isn't loadable on Android due to permissions restrictions
    func testLibXMLJNA() throws {
        if isAndroid {
            throw XCTSkip("Cannot load libxml2.so on Android")
        } else {
            libxml2.xmlCheckVersion(1)
        }
    }
    #endif
}


final class DarwinDirect {
    init() {
        #if SKIP
        // Android JNA error: "java.lang.IllegalStateException: The SecurityManager implementation on this platform is broken; you must explicitly provide the class to register"
        // com.sun.jna.Native.register("c")
        com.sun.jna.Native.register((DarwinDirect.self as kotlin.reflect.KClass).java, "c")
        #endif
    }

    // @JvmName is needed for test cases, since otherwise it is mangled to 'abs$SkipFFI_debugUnitTest'
    // SKIP INSERT: @JvmName("abs")
    // SKIP EXTERN
    func abs(_ value: Int32) -> Int32 { 
        #if canImport(Glibc)
        Glibc.abs(value)
        #else
        Darwin.abs(value)
        #endif
    }
}


#if SKIP

// MARK: BionicDarwin

private func BionicDarwin() -> BionicDarwin {
    com.sun.jna.Native.load("c", (BionicDarwin.self as kotlin.reflect.KClass).java)
}

private protocol BionicDarwin : com.sun.jna.Library {
    func abs(_ value: Int32) -> Int32

    func malloc(_ size: Int32) -> OpaquePointer
    func free(_ ptr: OpaquePointer) -> Int32

    func getenv(_ key: String) -> String?
}



// MARK: LibXMLLibrary

private func LibXMLLibrary() -> LibXMLLibrary {
    do {
        return com.sun.jna.Native.load("xml2", (LibXMLLibrary.self as kotlin.reflect.KClass).java)
    } catch let error as java.lang.UnsatisfiedLinkError { // "Unable to load library 'sqlite3'"
        // Android error: dlopen failed: library "libxml2.so" not found
        // dlopen failed: library "/system/lib64/libxml2.so" needed or dlopened by "/data/app/~~Si0U-ZTVh0DCUml9R7piBA==/skip.ffi.test-yqpzKeJq3mB0J3Ic4Pl8vA==/base.apk!/lib/arm64-v8a/libjnidispatch.so" is not accessible for the namespace "classloader-namespace"
        // This can happen when an app tries to load a system library that's not allowed in its namespace
        // Might be able to work around with the manifest: <application android:useLibrary="libxml2.so">
        //return com.sun.jna.Native.load("/system/lib64/libxml2.so", (LibXMLLibrary.self as kotlin.reflect.KClass).java)
        return com.sun.jna.Native.load("xml2", (LibXMLLibrary.self as kotlin.reflect.KClass).java)
    }

}

private protocol LibXMLLibrary : com.sun.jna.Library {
    func xmlGetVersion() -> OpaquePointer
    func xmlCheckVersion(version: Int32)
}

// MARK: SQLiteLibrary

private func SQLiteLibrary() -> SQLiteLibrary {
    do {
        return com.sun.jna.Native.load("sqlite3", (SQLiteLibrary.self as kotlin.reflect.KClass).java)
    } catch let error as java.lang.UnsatisfiedLinkError { // "Unable to load library 'sqlite3'"
        // on Android the sqlite3 lib is already loaded, so we can map to the current process for symbols
        // http://java-native-access.github.io/jna/5.13.0/javadoc/com/sun/jna/Native.html#load-java.lang.String-java.lang.Class-
        return com.sun.jna.Native.load(nil, (SQLiteLibrary.self as kotlin.reflect.KClass).java)
    }
}

private protocol SQLiteLibrary : com.sun.jna.Library {
    func sqlite3_open(_ filename: String, _ ppDb: com.sun.jna.ptr.PointerByReference?) -> Int32
    func sqlite3_close(_ ppDb: com.sun.jna.Pointer?) -> Int32

    func sqlite3_exec(_ ppDb: com.sun.jna.Pointer?, _ sql: String, _ callback: com.sun.jna.Pointer?, _ columns: com.sun.jna.Pointer?, _ errmsg: com.sun.jna.Pointer?) -> Int32

    func sqlite3_sleep(_ duration: Int32) -> Int32
}

extension SQLiteLibrary {
    var SQLITE_OPEN_READWRITE: Int32 { 2 }
    var SQLITE_OPEN_CREATE: Int32 { 4 }
}

// MARK: ZlibLibrary

private func ZlibLibrary() -> ZlibLibrary {
    com.sun.jna.Native.load("z", (ZlibLibrary.self as kotlin.reflect.KClass).java)
}

fileprivate func z_stream(next_in: OpaquePointer? = nil, avail_in: Int = 0, total_in: Int64 = 0, next_out: OpaquePointer? = nil, avail_out: Int = 0, total_out: Int64 = 0, msg: String? = nil, state: OpaquePointer? = nil, zalloc: OpaquePointer? = nil, zfree: OpaquePointer? = nil, opaque: OpaquePointer? = nil, data_type: Int = 0, adler: Int64 = 0, reserved: Int64 = 0) -> ZlibLibrary.z_stream_s {
        ZlibLibrary.z_stream_s(next_in: next_in, avail_in: avail_in, total_in: total_in, next_out: next_out, avail_out: avail_out, total_out: total_out, msg: msg, state: state, zalloc: zalloc, zfree: zfree, opaque: opaque, data_type: data_type, adler: adler, reserved: reserved)
}

private protocol ZlibLibrary : com.sun.jna.Library {
    func zlibVersion() -> OpaquePointer

    func compress(dest: ByteArray, destLen: Int32, source: ByteArray, sourceLen: Int32) -> Int32
    func uncompress(dest: ByteArray, destLen: Int32, source: ByteArray, sourceLen: Int32) -> Int32

    // SKIP INSERT: @com.sun.jna.Structure.FieldOrder("next_in", "avail_in", "total_in", "next_out", "avail_out", "total_out", "msg", "state", "zalloc", "zfree", "opaque", "data_type", "adler", "reserved")
    public class z_stream_s : com.sun.jna.Structure {
        // SKIP REPLACE: @JvmField var next_in: OpaquePointer?
        var next_in: OpaquePointer?
        // SKIP REPLACE: @JvmField var avail_in: Int
        var avail_in: Int
        // SKIP REPLACE: @JvmField var total_in: Long
        var total_in: Long
        // SKIP REPLACE: @JvmField var next_out: OpaquePointer?
        var next_out: OpaquePointer?
        // SKIP REPLACE: @JvmField var avail_out: Int
        var avail_out: Int
        // SKIP REPLACE: @JvmField var total_out: Long
        var total_out: Long
        // SKIP REPLACE: @JvmField var msg: String?
        var msg: String?
        // SKIP REPLACE: @JvmField var state: OpaquePointer?
        var state: OpaquePointer?
        // SKIP REPLACE: @JvmField var zalloc: OpaquePointer?
        var zalloc: OpaquePointer?
        // SKIP REPLACE: @JvmField var zfree: OpaquePointer?
        var zfree: OpaquePointer?
        // SKIP REPLACE: @JvmField var opaque: OpaquePointer?
        var opaque: OpaquePointer?
        // SKIP REPLACE: @JvmField var data_type: Int
        var data_type: Int
        // SKIP REPLACE: @JvmField var adler: Long
        var adler: Long
        // SKIP REPLACE: @JvmField var reserved: Long
        var reserved: Long

        init(next_in: OpaquePointer? = nil, avail_in: Int = 0, total_in: Int64 = 0, next_out: OpaquePointer? = nil, avail_out: Int = 0, total_out: Int64 = 0, msg: String? = nil, state: OpaquePointer? = nil, zalloc: OpaquePointer? = nil, zfree: OpaquePointer? = nil, opaque: OpaquePointer? = nil, data_type: Int = 0, adler: Int64 = 0, reserved: Int64 = 0) {
                self.next_in = next_in
                self.avail_in = avail_in
                self.total_in = total_in
                self.next_out = next_out
                self.avail_out = avail_out
                self.total_out = total_out
                self.msg = msg
                self.state = state
                self.zalloc = zalloc
                self.zfree = zfree
                self.opaque = opaque
                self.data_type = data_type
                self.adler = adler
                self.reserved = reserved
            }
    }

}

#endif
