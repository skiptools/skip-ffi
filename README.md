# SkipFFI

This is a [Skip](https://skip.tools) Swift/Kotlin library project that provides 
the capability for Skip's Kotlin transpiled code to call into C and C++ libraries
on Android.

On the Kotlin side, SkipFFI uses the Java Native Access ([JNA](https://github.com/java-native-access/jna))
library to simulate Swift types like `Swift.OpaquePointer` as `com.sun.jna.Pointer` pointer references, 
and implements `Swift.withUnsafeMutablePointer` using a `com.sun.jna.ptr.PointerByReference` on the Java side.

This capability is used by Skip frameworks like [SkipScript](https://source.skip.tools/skip-script) to 
provide a unified API to underlying native C APIs on both Darwin and Android.

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
