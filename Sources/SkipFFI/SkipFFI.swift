// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

#if SKIP
/// A  JNA `com.sun.jna.Pointer` is the equivalent of a Swift `OpaquePointer`
public typealias OpaquePointer = com.sun.jna.Pointer
public typealias UnsafeMutableRawPointer = com.sun.jna.ptr.PointerByReference

public typealias UnsafeMutablePointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeMutableBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafeBufferPointer<Element> = UnsafeMutableRawPointer
public typealias UnsafePointer<Pointee> = UnsafeMutableRawPointer
public typealias UnsafeMutableRawBufferPointer = UnsafeMutableRawPointer
public typealias UnsafeRawBufferPointer = UnsafeMutableRawPointer
public typealias UnsafeRawPointer = UnsafeMutableRawPointer

public typealias SkipFFIStructure = com.sun.jna.Structure


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

//public func withUnsafeMutableBytes<T, Result>(of value: inout T, _ body: (Any /* UnsafeMutableRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeBytes<T, Result>(of value: inout T, _ body: (Any /* UnsafeRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeBytes<T, Result>(of value: T, _ body: (Any /* UnsafeRawBufferPointer */) throws -> Result) rethrows -> Result { fatalError() }
//public func withUnsafeTemporaryAllocation<R>(byteCount: Int, alignment: Int, _ body: (Any /* UnsafeMutableRawBufferPointer */) throws -> R) rethrows -> R { fatalError() }
//public func withUnsafeTemporaryAllocation<R>(of type: Any /* T.Type */, capacity: Int, _ body: (Any /* UnsafeMutableBufferPointer<T> */) throws -> R) rethrows -> R { fatalError() }



#endif
