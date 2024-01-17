# SkipFFI

This is a [Skip](https://skip.tools) Swift/Kotlin library project that provides 
the capability for Skip's Kotlin transpiled code to call into C and C++ libraries
on Android.

On the Kotlin side, SkipFFI uses the Java Native Access ([JNA](https://github.com/java-native-access/jna))
library to simulate Swift types like `Swift.OpaquePointer` as `com.sun.jna.Pointer` pointer references, 
and implements `Swift.withUnsafeMutablePointer` using a `com.sun.jna.ptr.PointerByReference` on the Java side.

This capability is used by Skip frameworks like
[SkipSQL](https://source.skip.tools/skip-sql) and
[SkipScript](https://source.skip.tools/skip-script) to
provide a unified API to underlying native C APIs on both Darwin and Android.

## Example

```swift
#if !SKIP
import Darwin
#else
import SkipFFI
let Darwin = BionicDarwin()
#endif

// Full-qualified Module.fname() will call through SkipFFI to the C interface
Darwin.abs(-12) // 12
Darwin.free(Darwin.malloc(8))


// MARK: Implementation of C interface

func BionicDarwin() -> BionicDarwin {
    com.sun.jna.Native.load("c", (BionicDarwin.self as kotlin.reflect.KClass).java)
}

protocol BionicDarwin : com.sun.jna.Library {
    func abs(_ value: Int32) -> Int32

    func malloc(_ size: Int32) -> OpaquePointer
    func free(_ ptr: OpaquePointer) -> Int32

    func getenv(_ key: String) -> String?
}

```


## Implementation

SkipFFI's implementation provides:

```swift
public typealias OpaquePointer = com.sun.jna.Pointer
public typealias UnsafeMutableRawPointer = com.sun.jna.ptr.PointerByReference

public func withUnsafeMutablePointer<T>(to pointerRef: InOut<OpaquePointer?>, block: (UnsafeMutableRawPointer) throws -> T) rethrows -> T
```

## Working with Data

SkipFFI doesn't work with the Foundation Data API directly.

If you need to access raw bytes, you can use the APIs directly:

```swift

let blob = Data(…)
let size = blob.count

#if SKIP
let buf = java.nio.ByteBuffer.allocateDirect(size)
buf.put(blob.kotlin(nocopy: true)) // transfer the bytes
let ptr = com.sun.jna.Native.getDirectBufferPointer(buf)
try check(code: SQLite3.sqlite3_bind_blob(stmnt, index, ptr, size, nil))
#else
try blob.withUnsafeBytes { ptr in
    try check(code: SQLite3.sqlite3_bind_blob(stmnt, index, ptr.baseAddress, size, nil))
}
#endif
```

## Embedded C Code

With SkipFFI you can embed C code in your dual-platform Skip framework,
and use SkipFFI to create an idiomatic wrapper around the code that can
be used both from Swift and the transpiled Kotlin.

SkipFFI can be used to provide a direct interface from your transpiled Kotlin to
an embedded C library. It configures gradle's support for cmake build files and the
Android NDK toolchain to build the embedded C library for each of Android's supported
architectures, much in the same way as Xcode and SwiftPM handle building and linking
C source with Swift code for various architectures.

See the [Skip C Demo](http://source.skip.tools/skip-c-demo) sample project for an
example of using C files to provide a unified API to both Swift and Kotlin.


## Local vs. Instrumeted Testing

When you build and test the `skip-c-demo` project out of the box, either from Xcode or the Terminal using `swift test`, the normal Skip testing process will occur: the Swift test cases will be compiled an run against the macOS architecture, and then the special `XCSkipTests` will cause the `SkipUnit` framework to invoke `gradle test` against the transpiled source and test case files. And while this does work transparently with any embedded C files, you should be aware that since local testing run on the local macOS JVM, it isn't actually exercising the cross-compiled Android native libraries. It is, rather, linking to the locally-built C library that was built by SwiftPM.

This is the fastest way to test the native SkipFFI bridging, but when your C code needs to interface with libraries that are only available on Android (such as the various NDK APIs: [https://developer.android.com/ndk/guides/stable_apis](https://developer.android.com/ndk/guides/stable_apis)), then you will need to test non-locally, against an actual Android emulator or device.

In order to test the cross-compiled shared libraries on a real Android system, you need to run the instrumented tests against an Android simulator or device. This is accomplished by launching a simulator from the Android Studio Device Manager and then obtaining the device identifier with the `adb devices` terminal command. If you have a device with the id "emulator-5554", you can then run the transpiled tests against the simulator with the command:

```plaintext
ANDROID_SERIAL=emulator-5554 swift test
```

Similarly, you can set the `ANDROID_SERIAL` environment variable in the Run Arguments screen of the Xcode scheme for the target you are testing, which will have the same effect of running the instrumented tests against the specified emulator or device.



## Building

This project is a Swift Package Manager module that uses the
[Skip](https://skip.tools) plugin to transpile Swift into Kotlin.

Building the module requires that Skip be installed using 
[Homebrew](https://brew.sh) with `brew install skiptools/skip/skip`.
This will also install the necessary build prerequisites:
Kotlin, Gradle, and the Android build tools.

## Testing

The module can be tested using the standard `swift test` command
or by running the test target for the macOS destination in Xcode,
which will run the Swift tests as well as the transpiled
Kotlin JUnit tests in the Robolectric Android simulation environment.

Parity testing can be performed with `skip test`,
which will output a table of the test results for both platforms.
