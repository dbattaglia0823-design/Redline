# REDLINE mobile export and device checks

The Android and iOS presets target ARM64 and support portrait and landscape. They include the runtime vehicle, engine, and career manifests. They exclude tests, captures, reference art, source atlases, vehicle masters, and desktop-only per-vehicle engine samples. Mobile uses the existing shared engine family samples. Its retained vehicle texture cache is capped at 20 MiB, plus resources needed for the current frame.

The source asset audit found about 404 MiB of vehicle files and 167 MiB of audio before export filtering. The Android resource pack generated on Windows was about 295 MiB and started in a desktop headless smoke test. APK and IPA sizes depend on platform templates and signing.

## Android

Install the Godot 4.6.3 export templates, Java 17, and the Android SDK. Set the Java and Android SDK paths in Godot's editor settings. Create the output directory and export the Android preset as a debug APK for device testing. Configure release signing outside version control before distributing the APK. Use a signed Gradle AAB when preparing a Play Store release. [Godot Android export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)

## iOS

On macOS, install Xcode and the matching Godot export templates. Enter your Apple team ID in the iOS preset, then export into an empty directory and open the generated Xcode project. Select your signing identity and test on a device. The repository contains no signing credentials. [Godot iOS export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html)

## Validation

Run `python tools/run_regressions.py --godot /path/to/godot --graphical` on a desktop with graphics support. The race HUD and career tests exercise desktop and phone-sized layouts, including synthetic safe-area insets. These checks use a desktop window with simulated touch events.

Physical-device checks still needed include rotation during a race, notch and home-indicator clearance, simultaneous throttle and clutch input, swipe and tap behavior, audio latency, interrupted saves, cold start, and sustained frame rate and memory use on representative Android and iOS devices. Signed release builds and store submission also require platform credentials and tooling.
