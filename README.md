# Photo Wall

A Flutter Android take-home project exploring remote image loading, custom caching,
memory management, and bounded concurrency.

## Current status

Phase 2 adds a lazy three-column gallery of 100 distinct remote photos, a
full-screen viewer, back navigation with preserved scroll position, loading
indicators, and per-image retry controls. Phase 1 was successfully run on Android
by the project owner.

Phase 3 now stores compressed images in a custom 100 MiB disk cache. The app
checks disk before network and retains files across restarts. Decoded images
still use Flutter's framework cache; the custom 32 MiB memory cache and loading
scheduler are planned for Phases 4-5.
Forui 0.11.1 provides the light/dark themes, gallery and viewer headers, loading
indicator, and retry control. The grid remains a lazy Flutter GridView.
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

Tests cover grid layout/lazy construction, catalog identity and image sizing,
selected-photo navigation, both back paths with scroll retention, image retry,
stale completion, and disposal during retry. Tests use local image fixtures and
controlled image providers; they do not depend on live image servers.
The UI suite also checks the Forui gallery at narrow Android width in dark mode.
Cache, scheduler, and memory-pressure tests will accompany those implementations.

## Architecture

~~~text
lib/
  main.dart
  app/photo_wall_app.dart
  features/photos/
    models/photo.dart
    models/photo_catalog.dart
    screens/photo_wall_screen.dart
    screens/photo_viewer_screen.dart
    widgets/photo_image.dart
test/
  app_test.dart
  photo_catalog_test.dart
  photo_navigation_test.dart
  photo_image_test.dart
  support/test_images.dart
~~~

UI remains in features/photos. Future loading, decoding, scheduling, and cache
code will live in core/images, created when those components are implemented.
Dependencies will be introduced only when needed.

## Photo source and current behavior

The catalog is a checked-in metadata snapshot of 100 distinct photo IDs from
[Lorem Picsum](https://picsum.photos/), so startup does not need a metadata API
request. Photos download remotely using stable ID URLs. Grid requests use 400px
square crops; viewer requests preserve the source aspect ratio and cap the longest
side at 1600px without upscaling. Photographer names appear in the viewer.

Tap a tile to open it. Use the app bar back button or Android back to return.
A spinner indicates loading; the retry icon has a descriptive tooltip and retries
a failed image after evicting its framework cache entry. Successfully cached image
variants can load offline until Android clears app cache storage. A cached thumbnail
does not imply that its separate full-screen variant is cached.

## Planned memory cache and eviction

Not implemented. The plan is an LRU cache of decoded images with an approximately
32 MB budget, explicit byte accounting, and size-aware cache keys. Image ownership
must allow eviction without invalidating images that widgets still display.
The cache budget is not a cap on total process memory.

## Disk cache and eviction

The app creates a photo_wall_images directory inside the app's temporary cache.
Compressed image files use SHA-256 URL keys. A versioned JSON index records file
size and last access. Reads update recency; writes and index updates are serialized.
At 100 MiB of committed image files, least-recently-used files are evicted.
Files larger than the budget are displayed without disk admission. Startup
reconciles actual file lengths, missing files, stale metadata, partial writes,
and orphan files. An unreadable or missing entry becomes a network miss.

Downloaded responses are bounded to 20 MiB in memory. Disk write failures from
the filesystem do not prevent displaying already-downloaded bytes. Temporary
download buffers and index files are additional usage outside the 100 MiB payload
budget. The OS may clear the app cache at any time; offline use is best effort.
Image decode failure from a disk hit invalidates the entry and retries network once.

The planned streaming download and per-file pinning in the TRD are not yet
implemented. Phase 5 will handle deduplicating and limiting concurrent requests.
The disk layer does not enforce the memory budget.

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

Validation status:

- Phase 1 formatting, analysis, and startup test passed.
- The owner confirmed that Phase 1 runs on Android.
- Phase 2 automated validation is recorded in the implementation plan.
- Phase 3 disk cache tests cover restart persistence, LRU eviction, oversized
  entries, recovery, concurrent writes, and avoiding a repeat download.
- An Android 15 emulator is now detected as emulator-5556.
- A Phase 2 debug build from the agent session still fails with
  java.io.IOException: Unable to establish loopback connection.
  This is separate from the owner's successful local Phase 1 launch.
- Phase 2 on-device interaction and performance verification remain pending.

To verify Phase 2 locally, restart the running app (or run flutter run), scroll
through the gallery, open a photo, try both back controls, and confirm the scroll
position is retained. With an uncached image, disable connectivity to check its
error state, then restore connectivity and retry. Framework caching can keep
already-loaded images visible while offline.

The generated release configuration currently uses debug signing. Release
packaging and signing decisions will be reviewed during submission preparation.

## Tradeoffs and incomplete features

This is a Phase 3 checkpoint, not a complete submission. Bounded
downloads/decodes, the custom decoded memory cache, explicit decoded-image
lifecycle control, memory-pressure handling, the debug panel, and a verified
final APK remain outstanding. Native integration is not implemented.
