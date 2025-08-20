// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
#if os(macOS) || os(Linux)
import Foundation
import SkipTest

/// This test case will run the transpiled tests for the Skip module.
@available(macOS 13, macCatalyst 16, *)
final class XCSkipTests: XCTestCase, XCGradleHarness {
    public func testSkipModule() async throws {
        // Run the transpiled JUnit tests for the current test module.
        // These tests will be executed locally using Robolectric.
        // Connected device or emulator tests can be run by setting the
        // `ANDROID_SERIAL` environment variable to an `adb devices`
        // ID in the scheme's Run settings.
        //
        // Note that it isn't currently possible to filter the tests to run.
        try await runGradleTests()
    }
}
#endif

/// True when running in a transpiled Java runtime environment
let isJava = ProcessInfo.processInfo.environment["java.io.tmpdir"] != nil
/// True when running within an Android environment (either an emulator or device)
let isAndroid = isJava && ProcessInfo.processInfo.environment["ANDROID_ROOT"] != nil
/// True is the transpiled code is currently running in the local Robolectric test environment
let isRobolectric = isJava && !isAndroid
/// True if the system's `Int` type is 32-bit.
let is32BitInteger = Int64(Int.max) == Int64(Int32.max)
#if os(macOS)
let isMacOS = true
#else
let isMacOS = false
#endif
