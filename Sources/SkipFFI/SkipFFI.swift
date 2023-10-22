// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

#if SKIP
/// A  JNA `com.sun.jna.Pointer` is the equivalent of a Swift `OpaquePointer`
public typealias OpaquePointer = com.sun.jna.Pointer

public func withUnsafeMutablePointer<T>(to pointerRef: InOut<OpaquePointer?>, block: (com.sun.jna.ptr.PointerByReference?) throws -> T) rethrows -> T {
    let pref = com.sun.jna.ptr.PointerByReference()
    defer {
        // transfer the pointer result to the InOut
        pointerRef.value = pref.value
    }
    return try block(pref)
}
#endif
