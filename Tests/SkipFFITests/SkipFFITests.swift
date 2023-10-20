// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org
import XCTest
import OSLog
import Foundation

let logger: Logger = Logger(subsystem: "SkipFFI", category: "Tests")

@available(macOS 13, *)
final class SkipFFITests: XCTestCase {
    func testSkipFFI() throws {
        XCTAssertEqual(12, Darwin.abs(-12))
    }
}

#if SKIP
// workaround for Skip converting "JavaScriptCode.self.javaClass" to "(JavaScriptCoreLibrary::class.companionObjectInstance as JavaScriptCoreLibrary.Companion).java)"
// SKIP INSERT: fun <T : Any> javaClass(kotlinClass: kotlin.reflect.KClass<T>): Class<T> { return kotlinClass.java }

let Darwin: BionicCompatLibrary = {
    com.sun.jna.Native.load("c", javaClass(BionicCompatLibrary.self))
}()

protocol BionicCompatLibrary : com.sun.jna.Library {
    func abs(_ value: Int) -> Int
}

#endif

