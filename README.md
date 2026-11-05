# Photo Wall

Photo Wall is a Flutter gallery of 100 remote Picsum photos. It demonstrates a
bounded decoded-image cache, a persistent disk cache, controlled image loading,
and memory-aware image ownership. The required submission target is Android.

## 1. Run the app

The project has been built in CI with Flutter 3.29.2 and Dart 3.7.2. Install
Flutter, Android Studio, and an Android SDK, then start an emulator or connect an
Android device. From the repository root:

```sh
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

To run checks locally:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The
[Android workflow](.github/workflows/android-apk.yml) also uploads an APK under
the successful run's **Artifacts** section. Workflow artifacts expire after 14
days; the final APK should be attached to a GitHub Release.

The optional iOS host can be built on macOS with Xcode. A physical iPhone needs
development signing. The unsigned simulator build produced by CI cannot be
installed directly on an iPhone from Windows.

## 2. Architecture and project structure

| Area | Responsibility |
| --- | --- |
| `lib/features/photos/` | Three-column lazy gallery, viewer, live cache panel, detailed diagnostics, loading and retry states. |
| `lib/core/images/decoded_image_loader.dart` | Memory-first loading, shared requests, source recovery, decode ownership, and cancellation. |
| `lib/core/images/memory_image_cache.dart` | Custom decoded-image LRU and byte budget. |
| `lib/core/images/disk_image_cache.dart` | Persistent compressed files, index recovery, and disk LRU. |
| `lib/core/images/image_bytes_repository.dart` | Disk-before-network lookup, bounded HTTP responses, and a reusable HTTP client. |
| `lib/core/images/load_scheduler.dart` | Three permits across disk, network, and decode stages. |
| `android/` and `ios/` | Optional native thumbnail downsampling; Android also reports system memory information. |

The catalog is a checked-in snapshot of 100 distinct Picsum IDs, so startup does
not require a catalog API call. Grid URLs request a 400 px square crop. Viewer
URLs preserve aspect ratio and cap the longest side at 1600 px. Tapping a tile
opens the full-screen viewer; Back returns to the same grid scroll position.

The activity button in the gallery header toggles a small **live cache panel over
the grid**. It shows memory and disk bytes, memory evictions, and ongoing
downloads and decodes while the gallery scrolls. Its **Details / clear** button
opens the full diagnostics screen, including manual cache clearing and Android
memory information.

## 3. Memory cache and eviction

Grid thumbnails use a custom `LinkedHashMap` LRU cache capped at 32 MiB of
decoded pixels. Each entry is charged `width * height * 4` bytes. A hit moves the
entry to the most-recent position. Admission evicts the oldest entries until the
new image fits; an oversized image is displayed without being cached.

The cache owns one `ui.Image` handle per entry. A widget receives a clone and
disposes its handle after it stops rendering. Eviction therefore cannot dispose
an image that is still visible. Full-screen decodes are not admitted to the
shared thumbnail cache and are released when the viewer closes. The 32 MiB
budget covers cache-owned images, not visible clones or temporary decode buffers.

## 4. Disk cache and eviction

Compressed responses are stored in the app's temporary cache directory under
SHA-256 URL keys. The disk payload budget is 100 MiB. An index records file
lengths and access times; the oldest files are removed when a write exceeds the
budget. Writes use a `.part` file followed by a rename, and the index has a
backup. Startup reconciles missing files, partial files, orphans, and stale
metadata.

Thumbnail priority is **decoded memory → disk → network**. A valid disk hit
does not download again. If a disk image cannot be decoded, its entry is
invalidated and the network is tried once. Read access times update in memory;
index writes are limited to roughly once every two seconds and flushed when
the app backgrounds. Writes, evictions, and manual clearing persist immediately.
The OS may remove app cache files, so offline access is best effort.

## 5. Memory pressure and viewer lifetime

A lifecycle-owned `WidgetsBindingObserver` trims the decoded cache when Flutter
reports memory pressure. An admission epoch prevents loads started before that
signal from immediately refilling it. Visible clone handles remain valid. The
viewer owns its full-screen image and releases it on route disposal; repeated
open/back tests check that old viewer handles are disposed.

The Android `getMemoryInfo` result is displayed in detailed diagnostics. It is
not used as a polling-based trim trigger: system-wide available memory is not an
app-specific allocation limit. Flutter's memory-pressure signal and the hard
32 MiB cache budget drive trimming.

## 6. Native platform integration

The optional MethodChannel is `com.assignment.photowall/image`.
`decodeDownsampled` accepts a local path or compressed bytes, maximum dimensions,
and PNG/JPEG output format; it returns dimensions and compressed bytes. Android
uses `BitmapFactory` on a three-thread executor. iOS uses ImageIO on a background
queue. Grid thumbnails call it after disk/network resolution, then Flutter
decodes the returned bytes for display. The full-screen viewer uses Flutter's
decoder directly.

If the native channel fails, Flutter decodes the original compressed bytes.
A channel failure therefore does not invalidate a valid disk file. When a
thumbnail is no longer needed, the loader cancels active HTTP work and tells the
native worker to skip remaining stages. A codec call already underway may still
finish; its result is discarded. Android's `getMemoryInfo` reports approximate
available, total, threshold, and low-memory values for the detailed panel.

## 7. Tradeoffs and limitations

- One scheduler limits the complete image pipeline to three active jobs. Viewer
  requests have queue priority; newer queued grid requests run before older
  ones, while jobs already running are not preempted.
- A shared `HttpClient` can reuse keep-alive connections. Each response is capped
  at 20 MiB and buffered before decode and disk write. This avoids a second
  file read but temporarily uses memory outside the decoded cache budget.
- Native downsampling satisfies the optional channel exercise, but a 400 px
  source is already small. Re-encoding and the second Flutter decode add CPU and
  copies; no performance gain is claimed without device measurements.
- Forui supplies themes and header controls; the grid, caches, scheduler, and
  image pipeline remain project code. The current checks use Flutter 3.29.2;
  compatibility with newer stable releases has not been established.
- The CI APK uses debug signing for this assignment. An Android install with a
  different signing key cannot replace it without uninstalling the old build,
  which clears that app's local cache and data.

## 8. Incomplete features and validation

The required Android features are implemented. Automated tests cover cache
budgets and eviction, restart and corrupt-file recovery, concurrency, native
fallback, stale results, navigation, memory pressure, and the live panel.
Formatting, analysis, and Flutter tests must pass before delivery.

The [Phase 9 Android workflow](https://github.com/Agamjot27/Photo-Wall/actions/runs/41979856858)
built an APK that the project owner installed on an Android Studio emulator.
Gallery/viewer navigation, diagnostics, cache clearing, and reopening a cached
photo offline worked there. The [Phase 10 Android APK](https://github.com/Agamjot27/Photo-Wall/actions/runs/41992822705)
and [iOS simulator build](https://github.com/Agamjot27/Photo-Wall/actions/runs/41992822607)
passed CI. Current local changes still need CI compilation and a smoke check of
their final Android APK. Physical-device performance profiling and an iOS
runtime test have not been performed. A durable GitHub Release APK attachment
is still needed for submission.

See the [product requirements](docs/PRD.md), [technical design](docs/TRD.md),
[phase history](docs/implementation-plan.md), and [release checklist](docs/release-checklist.md)
for supporting decisions and verification steps.
