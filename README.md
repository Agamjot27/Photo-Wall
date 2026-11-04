# Photo Wall

A Flutter Android take-home project exploring remote image loading, custom caching,
memory management, and bounded concurrency.

## Current status

Phase 1 source foundation is implemented: Android scaffold, app entry point,
a placeholder Photo Wall screen, strict analysis, and a startup widget test.
The gallery and image-loading system are not implemented yet.
See [the implementation plan](docs/implementation-plan.md) for phase boundaries.

## Requirements and design

- [Product requirements](docs/PRD.md): assignment scope, user flows, and acceptance criteria.
- [Technical requirements](docs/TRD.md): architecture, cache ownership, concurrency, and verification.
- [Implementation plan](docs/implementation-plan.md): delivery phases and commit boundaries.

The requirements documents describe the intended implementation; the current status
above records what exists today.

## Toolchain and setup

The initial scaffold was generated and checked with Flutter 3.29.2 stable,
Dart 3.7.2, and Android Studio's Java 17. The Android application ID is
com.assignment.photo_wall. Only Android is configured.

1. Install Flutter and Android Studio with the Android SDK, build tools,
   platform tools, and Android SDK Command-line Tools.
2. Run flutter doctor -v and resolve Android toolchain issues.
3. Review and accept the applicable SDK licenses with flutter doctor --android-licenses.
4. Start an Android emulator or connect an Android phone with USB debugging enabled.
5. From the repository root, run:

~~~sh
flutter pub get
flutter devices
flutter run -d <android-device-id>
~~~

## Quality checks

~~~sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

The startup test verifies that the app opens on the Photo Wall screen.
Cache, concurrency, and lifecycle tests will accompany those implementations.

## Architecture

~~~text
lib/
  main.dart                              # App entry point
  app/photo_wall_app.dart                # MaterialApp and theme
  features/photos/screens/
    photo_wall_screen.dart               # Initial feature screen
test/
  app_test.dart                          # Startup smoke test
~~~

UI remains in features/photos. Future loading, decoding, scheduling, and cache
code will live in core/images, created when those components are implemented.
Dependencies will be introduced only when needed.

## Planned memory cache and eviction

Not implemented. The plan is an LRU cache of decoded images with an approximately
32 MB budget, explicit byte accounting, and size-aware cache keys. Image ownership
must allow eviction without invalidating images that widgets still display.
The cache budget is not a cap on total process memory.

## Planned disk cache and eviction

Not implemented. Downloaded compressed images will persist locally with an
approximately 100 MB limit and eviction of older entries. Loading will prefer
memory, then disk, then network.

## Planned memory-pressure handling

Not implemented. A WidgetsBindingObserver will aggressively trim cached decoded
images on memory pressure. Full-screen image ownership will be released on exit.

## Optional native integration

Not implemented. Android MethodChannel downsampling and memory information are
reserved for a separate bonus phase after the required functionality is stable.

## Android build and validation status

~~~sh
flutter build apk --debug
flutter build apk --release
~~~

Flutter writes APKs under build/app/outputs/flutter-apk/. Build outputs are ignored
by Git; the eventual submission APK should be attached to a GitHub release.

Phase 1 checks on 2026-11-04:

- Formatting: passed.
- flutter analyze: passed with no issues.
- flutter test: passed (one startup widget test).
- Android debug build: blocked by Java/Gradle reporting
  java.io.IOException: Unable to establish loopback connection.
  A retry with Java IPv4 preference produced the same error.
- flutter doctor also reported missing Android command-line tools and unknown
  Android license status.
- No Android device was connected, so an on-device launch is not yet verified.

The generated release configuration currently uses debug signing. Release
packaging and signing decisions will be reviewed during submission preparation.

## Tradeoffs and incomplete features

This is a foundation checkpoint, not a complete submission. The 100-image grid,
full-screen viewer, both caches, loading scheduler, memory-pressure handling,
debug panel, and final APK remain outstanding. Visual design is intentionally
minimal while the image-loading behavior is built and tested.
