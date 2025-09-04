// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
import Foundation

#if SKIP
public typealias SkipFFIStructure = com.sun.jna.Structure
#else
/// A protocol for a type that implements a C struct
public protocol SkipFFIStructure {
}
#endif

// MARK: UInt handling

#if !SKIP
public typealias FFIUInt = UInt
public typealias FFIUInt8 = UInt8
public typealias FFIUInt16 = UInt16
public typealias FFIUInt32 = UInt32
public typealias FFIUInt64 = UInt64
#else
public typealias FFIUInt = Int64 // Java has no native UInt
public typealias FFIUInt8 = Int8 // Java has no native UInt
public typealias FFIUInt16 = Int16 // Java has no native UInt
public typealias FFIUInt32 = Int32 // Java has no native UInt
public typealias FFIUInt64 = Int64 // Java has no native UInt
#endif


#if SKIP
/// A  JNA `com.sun.jna.Pointer` is the equivalent of a Swift `OpaquePointer`
public typealias OpaquePointer = com.sun.jna.Pointer
public typealias Memory = com.sun.jna.Memory
public typealias UnsafePointer<Pointee> = OpaquePointer
public typealias UnsafeRawPointer = OpaquePointer

public typealias UnsafeMutableRawPointer = com.sun.jna.ptr.PointerByReference

public typealias UnsafeMutablePointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeMutableBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeMutableRawBufferPointer = UnsafeMutableRawPointer
public typealias UnsafeRawBufferPointer = UnsafeMutableRawPointer

// TODO: static extensions on typealias don't work; we would need to make this a wrapper struct for it to work
//public extension UnsafeMutablePointer {
//    public static func allocate(capacity: Int) -> Memory {
//        let mem = com.sun.jna.Memory(Int64(capacity))
//        mem.clear()
//        return mem
//    }
//}
//
//public extension Memory {
//    func deallocate() {
//        dispose() // this would happen during GC, but doing it manually frees up the memory sooner
//    }
//}

public extension UnsafeMutableRawPointer {
    var baseAddress: OpaquePointer {
        return getValue()
    }
}

public func withUnsafeMutablePointer<T>(to pointerRef: InOut<OpaquePointer?>, block: (UnsafeMutableRawPointer) throws -> T) rethrows -> T {
    let pref = UnsafeMutableRawPointer()
    defer {
        // transfer the pointer result to the InOut
        pointerRef.value = pref.value
    }
    return try block(pref)
}

/// `Swift.String.init(cString:)` can be replicated using `com.sun.jna.Pointer.getString(offset)`
public func String(cString: OpaquePointer) -> String {
    cString.getString(0)
}

public func Data(bytes: UnsafeRawPointer, count: Int) -> Data {
    return Data(platformValue: bytes.getByteArray(0, count))
}

extension Data {
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        let buf = java.nio.ByteBuffer.allocateDirect(self.count)
        buf.put(self.kotlin(nocopy: true))
        let ptr = com.sun.jna.Native.getDirectBufferPointer(buf)
        return body(com.sun.jna.ptr.PointerByReference(ptr))
    }

    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        let byteArray = self.kotlin(nocopy: true)
        let len = self.count
        let buf = java.nio.ByteBuffer.allocateDirect(len)
        buf.put(byteArray)
        //buf.flip()
        let ptr = com.sun.jna.Native.getDirectBufferPointer(buf)
        let ptrRef = com.sun.jna.ptr.PointerByReference(ptr)
        let result = body(ptrRef)


        let byteArray2 = PlatformData(len)
        ptrRef.value.read(0, byteArray2, 0, len)
        return result
    }
}
internal typealias PlatformData = kotlin.ByteArray

#endif


/// Registers the class for the given instances to act as the JNA native proxy
public func registerNatives<T: AnyObject>(_ instance: T, frameworkName: String, libraryName: String) -> T {

    #if SKIP
    let clazz = type(of: instance)

    do {
        // should be bundled from the C module in jni/arm64-v8a/libclibrary.so
        com.sun.jna.Native.register(clazz.java, libraryName)
    } catch let error as java.lang.UnsatisfiedLinkError {
        if ProcessInfo.processInfo.environment["ANDROID_ROOT"] != nil {
            // we are running on Android and not Robolectric, so just re-throw the error
            throw error
        }

        let os = System.getProperty("os.name")
        let isLinux = os.lowercase().contains("linux")

        let libext = isLinux ? "so" : "dylib"
        let libpath = "lib\(frameworkName).\(libext)"

        let arch = System.getProperty("os.arch") // amd64 => x86_64 on Linux, aarch64 => arm64 on macOS
        let libx86 = isLinux ? "x86_64-unknown-linux-gnu" : "x86_64-apple-macosx"
        let libarm = isLinux ? "aarch64-unknown-linux-gnu" : "arm64-apple-macosx"

        // for Robolectric we link against out locally-built library version created by either Xcode or SwiftPM
        var frameworkPath: String
        if let bundlePath = ProcessInfo.processInfo.environment["XCTestBundlePath"] { // running from Xcode
            frameworkPath = bundlePath + "/../PackageFrameworks/\(frameworkName).framework/\(frameworkName)"
        } else { // SwiftPM doesn't set XCTestBundlePath and builds as a .dylib rather than a .framework
            var baseDir = FileManager.default.currentDirectoryPath + "/../../../../../.."
            frameworkPath = baseDir + "/\(libx86)/debug/\(libpath)" // check for Intel
            if !FileManager.default.fileExists(atPath: frameworkPath) { // no x86_64 … try ARM
                frameworkPath = baseDir + "/\(libarm)/debug/\(libpath)"
            }
            if !FileManager.default.fileExists(atPath: frameworkPath) { // handle new Swift 6 addition of "destination" to the build plugin output hierarchy
                baseDir += "/.."
                frameworkPath = baseDir + "/\(libx86)/debug/\(libpath)" // check for Intel (again)
                if !FileManager.default.fileExists(atPath: frameworkPath) { // no x86_64 … try ARM (again)
                    frameworkPath = baseDir + "/\(libarm)/debug/\(libpath)"
                }
            }
        }

        if !FileManager.default.fileExists(atPath: frameworkPath) {
            error.printStackTrace()
            print("SkipFFI.registerNatives: could not locate library \(libraryName) for framework \(frameworkName) at expected path: \(frameworkPath)")
        }
        com.sun.jna.Native.register(clazz.java, frameworkPath)
    }
    #endif
    return instance
}


#if SKIP
public typealias FFIDataPointer = com.sun.jna.Memory
#else
public typealias FFIDataPointer = UnsafeMutableRawPointer
#endif

/// Allocates the given `size` of memory and then invokes the block with the pointer, then returns the contents of the null-terminated string
public func withFFIDataPointer(size: Int, block: (FFIDataPointer) throws -> Int32) rethrows -> Data? {

    func read() throws -> Data {
        #if SKIP
        let dataPtr = FFIDataPointer(Int64(size))
        dataPtr.clear()
        defer { dataPtr.close() } // calls dispose() to deallocate
        #else
        let dataPtr = FFIDataPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<UInt8>.alignment)
        //defer { dataPtr.deallocate() } // we deallocate lazily from the Data
        #endif

        let read: Int32 = try block(dataPtr)

        #if SKIP
        let data: kotlin.ByteArray = dataPtr.getByteArray(0, read)
        return Data(platformValue: data)
        #else
        let data = Data(bytesNoCopy: dataPtr, count: Int(read), deallocator: .custom({ (pointer, _) in
            pointer.deallocate()
        }))
        return data
        #endif
    }

    var data = try read()
    // keep reading until read == size
    while data.count < size {
        data.append(contentsOf: try read())
    }
    return data
}


#if SKIP
public typealias FFIStringPointer = com.sun.jna.Memory
#else
public typealias FFIStringPointer = UnsafeMutablePointer<CChar>
#endif

/// Allocates the given `size` of memory and then invokes the block with the pointer, then returns the contents of the null-terminated string
public func withFFIStringPointer(size: Int, clear: Bool = true, block: (FFIStringPointer) throws -> Void) rethrows -> String? {
    #if SKIP
    // TODO: to mimic UnsafeMutablePointer<CChar>.allocate() we would need to create wrapper structs in SkipFFI (rather than raw typealiases)
    let stringMemory = FFIStringPointer(Int64(size + 1))
    if clear {
        stringMemory.clear()
    }
    defer { stringMemory.close() } // calls dispose() to deallocate
    #else
    let stringMemory = FFIStringPointer.allocate(capacity: Int(size + 1))
    if clear {
        stringMemory.initialize(repeating: 0, count: Int(size + 1))
    }
    defer { stringMemory.deallocate() }
    #endif

    try block(stringMemory)

    #if SKIP
    return stringMemory.getString(0)
    #else
    let entryName = String(cString: stringMemory)
    return entryName
    #endif
}
