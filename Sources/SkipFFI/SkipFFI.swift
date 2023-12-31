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



#endif
