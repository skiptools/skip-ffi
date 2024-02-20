// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

import Foundation

#if SKIP
public typealias SkipFFIStructure = com.sun.jna.Structure
#else
/// A protocol for a type that implements a C struct
public protocol SkipFFIStructure {
}
#endif

#if SKIP
/// A  JNA `com.sun.jna.Pointer` is the equivalent of a Swift `OpaquePointer`
public typealias OpaquePointer = com.sun.jna.Pointer
public typealias UnsafePointer<Pointee> = OpaquePointer
public typealias UnsafeRawPointer = OpaquePointer

public typealias UnsafeMutableRawPointer = com.sun.jna.ptr.PointerByReference

public typealias UnsafeMutablePointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeMutableBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeMutableRawBufferPointer = UnsafeMutableRawPointer
public typealias UnsafeRawBufferPointer = UnsafeMutableRawPointer

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

// Kotlin compile error: Platform declaration clash: The following declarations have the same JVM signature (withUnsafeMutablePointer(Lskip/lib/InOut;Lkotlin/jvm/functions/Function1;)Ljava/lang/Object;):
//public func withUnsafeMutablePointer<T>(to pointerRef: InOut<SkipFFIStructure>, block: (InOut<SkipFFIStructure>) throws -> T) rethrows -> T {
//    block(pointerRef)
//}


/// `Swift.String.init(cString:)` can be replicated using `com.sun.jna.Pointer.getString(offset)`
public func String(cString: OpaquePointer) -> String {
    cString.getString(0)
}

public func Data(bytes: UnsafeRawPointer, count: Int) -> Data {
    return Data(platformValue: bytes.getByteArray(0, count))
}

//public func withUnsafeMutableBytes<T, Result>(of value: inout T, _ body: (Any /* UnsafeMutableRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeBytes<T, Result>(of value: inout T, _ body: (Any /* UnsafeRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeBytes<T, Result>(of value: T, _ body: (Any /* UnsafeRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeTemporaryAllocation<R>(byteCount: Int, alignment: Int, _ body: (Any /* UnsafeMutableRawBufferPointer */) throws -> R) rethrows -> R { fatalError() }
//public func withUnsafeTemporaryAllocation<R>(of type: Any /* T.Type */, capacity: Int, _ body: (Any /* UnsafeMutableBufferPointer<T> */) throws -> R) rethrows -> R { fatalError() }


extension Data {
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        let buf = java.nio.ByteBuffer.allocateDirect(self.count)
        buf.put(self.kotlin(nocopy: true))
        let ptr = com.sun.jna.Native.getDirectBufferPointer(buf)
        return body(com.sun.jna.ptr.PointerByReference(ptr))
    }
}

#endif


/// Registers the class for the given instances to act as the JNA native proxy
public func registerNatives<T: AnyObject>(_ instance: T, frameworkName: String, libraryName: String) -> T {

    #if SKIP
    let clazz = type(of: instance)

    do {
        // should be bundled from the C module in jni/arm64-v8a/libclibrary.so
        com.sun.jna.Native.register(clazz.java, libraryName)
    } catch let error as java.lang.UnsatisfiedLinkError {
        // for Robolectric we link against out locally-built library version created by either Xcode or SwiftPM
        var frameworkPath: String
        if let bundlePath = ProcessInfo.processInfo.environment["XCTestBundlePath"] { // running from Xcode
            frameworkPath = bundlePath + "/../PackageFrameworks/\(frameworkName).framework/\(frameworkName)"
        } else { // SwiftPM doesn't set XCTestBundlePath and builds as a .dylib rather than a .framework
            let baseDir = FileManager.default.currentDirectoryPath + "/../../../../../.."
            frameworkPath = baseDir + "/x86_64-apple-macosx/debug/lib\(frameworkName).dylib" // check for Intel
            if !FileManager.default.fileExists(atPath: frameworkPath) { // no x86_64 … try ARM
                frameworkPath = baseDir + "/arm64-apple-macosx/debug/lib\(frameworkName).dylib"
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
