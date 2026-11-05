# Photo Wall

A Flutter Android take-home project exploring remote image loading, custom caching,
memory management, and bounded concurrency.

## Current status

Phase 2 adds a lazy three-column gallery of 100 distinct remote photos, a
full-screen viewer, back navigation with preserved scroll position, loading
indicators, and per-image retry controls. Phase 1 was successfully run on Android
by the project owner.

Phase 3 stores compressed images in a custom 100 MiB disk cache. The app checks
disk before network and retains files across restarts. Phase 4 adds a custom
32 MiB decoded-image LRU cache for grid thumbnails. Phase 5 limits active image
jobs to three and shares identical requests.
Phase 6 trims decoded images on system memory pressure. Phase 7 adds a live
diagnostics screen and manual cache clearing.
Phase 9 adds active HTTP cancellation and Android native thumbnail downsampling
and memory information. Phase 10 adds an optional iOS thumbnail channel.
Forui 0.11.1 provides the light/dark themes, gallery and viewer headers, and
loading indicator. Failed images use a labeled Material Retry button. The grid
remains a lazy Flutter GridView.
See [the implementation plan](docs/implementation-plan.md) for phase boundaries.

## Requirements and design

- [Product requirements](docs/PRD.md): assignment scope, user flows, and acceptance criteria.
- [Technical requirements](docs/TRD.md): architecture, cache ownership, concurrency, and verification.
- [Implementation plan](docs/implementation-plan.md): delivery phases and commit boundaries.
- [Android release checklist](docs/release-checklist.md): build, device checks, and recorded evidence.

The requirements documents describe the intended implementation; the current status
above records what exists today.

## Toolchain and setup

The initial scaffold was generated and checked with Flutter 3.29.2 stable,
Dart 3.7.2, and Android Studio's Java 17. The Android application ID is
com.assignment.photo_wall. Android and iOS host projects are configured; the iOS
host and Swift code still require a macOS build.

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

For the optional iOS host, use macOS with Xcode and CocoaPods, then run
`flutter pub get` and `flutter run -d <ios-device-id>`. The Android APK remains
the required submission artifact.

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
Diagnostics and cache-clear tests cover active-download races and persisted
disk clearing. Phase 8 acceptance tests follow a photo through memory, disk,
offline restart, and corrupt-disk recovery using the real decoder.

## Architecture

~~~text
lib/
  main.dart
  app/photo_wall_app.dart
  core/images/
    disk_image_cache.dart
    image_bytes_repository.dart
    memory_image_cache.dart
    decoded_image_loader.dart
    native_image_bridge.dart
    load_scheduler.dart
    memory_pressure_observer.dart
  features/photos/
    models/photo.dart
    models/photo_catalog.dart
    screens/photo_wall_screen.dart
    screens/photo_viewer_screen.dart
    screens/cache_diagnostics_screen.dart
    widgets/photo_image.dart
    widgets/decoded_photo_image.dart
test/
  app_test.dart
  photo_catalog_test.dart
  photo_navigation_test.dart
  photo_image_test.dart
  disk_image_cache_test.dart
  image_bytes_repository_test.dart
  memory_image_cache_test.dart
  decoded_image_loader_test.dart
  load_scheduler_test.dart
  image_loading_coordination_test.dart
  memory_pressure_test.dart
  viewer_lifecycle_test.dart
  photo_pipeline_acceptance_test.dart
  support/test_images.dart
~~~

UI remains in features/photos. Loading, decoding, and both caches live in
core/images, including the Phase 5 scheduler. Android native methods live in
android/app/src/main/kotlin/com/assignment/photo_wall; the iOS channel is in
ios/Runner/AppDelegate.swift.

## Photo source and current behavior

The catalog is a checked-in metadata snapshot of 100 distinct photo IDs from
[Lorem Picsum](https://picsum.photos/), so startup does not need a metadata API
request. Photos download remotely using stable ID URLs. Grid requests use 400px
square crops; viewer requests preserve the source aspect ratio and cap the longest
side at 1600px without upscaling. Photographer names appear in the viewer.

Tap a tile to open it. Use the app bar back button or Android back to return.
A spinner indicates loading; failed images offer Retry. Successfully cached image
variants can load offline until Android clears app cache storage. A cached
thumbnail does not imply that its separate full-screen variant is cached.

Remote requests have a 30-second overall limit. If a request or decode fails, the
photo shows a clear Retry button. A thumbnail and its full-screen image are
separate downloads, so a visible thumbnail can still lead to a viewer failure.

## Decoded memory cache and eviction

Grid thumbnails use a custom LRU cache with a hard 32 MiB limit. Each entry owns
a decoded ui.Image handle and accounts for width * height * 4 bytes. A cache hit
returns a clone handle to the widget and promotes the entry to most recently used.
Admission evicts the oldest entries until the new image fits. An image larger than
the limit is delivered to its current viewer without cache admission.

The widget owns and disposes its clone after it stops rendering. Cache eviction
disposes only the cache handle; a currently visible clone remains valid. Full-screen
images are not retained in the shared decoded cache and release their handle on
route disposal. Thumbnail decoding targets 400px width without upscaling.
The 32 MiB figure covers cache-owned decoded images, not visible clones,
in-flight decode buffers, or total process memory. The Phase 6 pressure observer
trims cache-owned handles when Android reports low memory.

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
implemented. Phase 5 handles identical-request sharing and limits concurrent jobs.
The disk layer does not enforce the memory budget.

## Loading coordination

A single three-slot scheduler covers each job from disk lookup through download
and decode. Full-screen requests enter a higher-priority queue; jobs already
running are not preempted. Identical active requests share one job. Each
subscriber receives its own decoded-image handle and can leave independently.
When the last subscriber leaves a queued job, it is removed before starting.
An active request receives a cancellation signal; its result is discarded if
the underlying operation finishes later. Widgets also check their request
generation before displaying a result, preventing a late response from
replacing another photo.

When the last subscriber leaves an active network request, the HTTP client is
closed and its scheduler slot is released after the request ends. A queued job
is removed before starting. A decode already underway cannot be interrupted,
but a cancelled result is disposed rather than displayed or cached. The
scheduler does not prefetch. Different URL variants do not share their
compressed source request.

## Cache diagnostics and clearing

Tap the activity icon in the gallery header to see live decoded-memory bytes,
compressed-disk bytes, memory eviction count, active downloads, active decodes,
and queued image jobs. Counters refresh while the screen is open. Cache sizes
cover stored entries, not visible image handles or temporary buffers.
On Android, the panel also shows available and total system memory, the low-memory
threshold, and the low-memory flag reported by ActivityManager.

The Clear caches button removes cache-owned decoded images and compressed files.
Visible images remain usable. Requests already in progress may finish displaying,
but an admission generation prevents their results from repopulating either cache.
Later image requests fetch again and can enter the caches normally. Manual clear
does not count as an LRU eviction.

## Memory pressure and viewer lifetime

A lifecycle-owned WidgetsBindingObserver listens for Flutter memory-pressure
notifications. It drops cache-owned decoded images, increments the eviction
counter, and advances an admission epoch. A request started before that
notification may still finish for a visible widget, but its image cannot
immediately repopulate the cache. Current widget handles remain valid because
they are separate clones. Disk files are unaffected.

Full-screen images bypass the shared decoded cache. The viewer owns its
decoded handle and releases it after navigation removes the image from the
frame. A repeated-open test verifies each prior viewer image is disposed.
The app also clears cache-owned handles when its root widget is disposed.

## Optional native integration

The Android bonus uses MethodChannel `com.assignment.photowall/image`.
`decodeDownsampled` accepts either a local path or compressed bytes plus output
limits and format; it returns output dimensions and compressed bytes. Android
uses BitmapFactory sampling, scales within the requested bounds, and encodes PNG
or JPEG on a background worker. Grid thumbnails invoke it after disk/network
resolution and then decode the returned JPEG with Flutter for display. The
full-screen viewer keeps the Flutter decode path. `getMemoryInfo` reports
ActivityManager's approximate available, total, threshold, and low-memory data.
The channel input/output is validated on the Dart side and covered by mock-channel
tests. Re-encoding introduces extra CPU and a temporary byte copy; it needs
Android profile testing before claiming a performance gain. The native Kotlin
code compiled in the Phase 9 cloud release workflow and was exercised on an
Android Studio emulator by the owner.
The iOS host uses ImageIO thumbnail sampling and returns the same compressed
image response. It does not expose Android ActivityManager memory information.
The iOS path has not yet been compiled or tested on a Mac or iOS device.

## Android build and validation status

~~~sh
flutter build apk --debug
flutter build apk --release
~~~

Flutter writes APKs under build/app/outputs/flutter-apk/. Build outputs are ignored
by Git; the eventual submission APK should be attached to a GitHub release.
The Android APK workflow also builds and stores a downloadable APK artifact on
GitHub after a push to main. That artifact still needs on-device verification.

Validation status:

- Phase 1 formatting, analysis, and startup test passed.
- The owner confirmed that Phase 1 runs on Android.
- Phase 2 automated validation is recorded in the implementation plan.
- Phase 3 disk cache tests cover restart persistence, LRU eviction, oversized
  entries, recovery, concurrent writes, and avoiding a repeat download.
- Phase 4 tests cover decoded-image LRU accounting, active clone safety,
  oversized-image admission, memory hits, viewer ownership, and late results.
- Phase 5 tests cover three-slot scheduling, viewer priority, failure cleanup,
  duplicate-request sharing, independent cancellation, and replacement races.
- Phase 6 tests cover memory-pressure trimming, stale admission prevention,
  active-image safety, observer cleanup, and repeated viewer disposal.
- Phase 7 tests cover persisted clearing and a download already running when
  the user clears both caches.
- Phase 8 tests cover cold/warm cache paths, offline restart, and corrupt-disk
  recovery using the production decoder.
- Phase 9 tests cover active HTTP cancellation, scheduler slot recovery,
  cancelled decode disposal, and the native MethodChannel response contract.
- Phase 10 adds an iOS host and ImageIO thumbnail channel. A macOS simulator
  workflow will check compilation after publication; no iOS runtime result is
  available yet.
- An Android 15 emulator is now detected as emulator-5556.
- The [first cloud release workflow](https://github.com/Agamjot27/Photo-Wall/actions/runs/41975602529)
  completed successfully and uploaded
  an APK artifact. That build predates the Phase 9 native code and has not been
  installed or smoke-tested here.
- The [Phase 9 release workflow](https://github.com/Agamjot27/Photo-Wall/actions/runs/41979856858)
  passed and uploaded an APK. The owner installed it on an Android Studio
  emulator and confirmed gallery/viewer navigation, diagnostics, cache clearing,
  and reopening a cached photo offline.
- The agent-session release build fails before Android compilation because the
  Gradle client cannot open its local daemon socket (`PipeImpl`,
  `Invalid argument: connect`). This is separate from the owner's successful
  local launch and does not establish whether the release APK builds locally.
- Emulator interaction checks passed; physical-device performance verification
  remains unavailable.

To verify Phase 2 locally, restart the running app (or run flutter run), scroll
through the gallery, open a photo, try both back controls, and confirm the scroll
position is retained. With an uncached image, disable connectivity to check its
error state, then restore connectivity and retry. Framework caching can keep
already-loaded images visible while offline.

The generated release configuration currently uses debug signing. Release
packaging and signing decisions will be reviewed during submission preparation.

## Tradeoffs and incomplete features

This is a Phase 10 checkpoint, not a complete submission. The Phase 9 Android
APK built and passed owner smoke checks on an emulator; the iOS bonus needs a
macOS build. Physical-device performance profiling remains outstanding. The
custom memory budget does not cap temporary or total process memory.
