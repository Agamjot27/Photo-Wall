# Photo Wall Technical Requirements Document

Version: 1.0
Date: 2026-11-04
Status: Proposed implementation baseline, not a claim that these components exist.
Repository: [Agamjot27/Photo-Wall](https://github.com/Agamjot27/Photo-Wall)

## Technical objective

Implement the [PRD](PRD.md) with an inspectable image pipeline, deterministic cache
policies, explicit decoded-image ownership, and bounded asynchronous work.
The supplied assignment defines mandatory behavior; policies below are project
design decisions where the assignment leaves implementation open.

The existing baseline uses Flutter 3.29.2, Dart 3.7.2, Android/Kotlin, and application
ID com.assignment.photo_wall. Verify API compatibility against that installed
SDK when implementing. No SDK upgrade is required by this document.

## Architecture and responsibilities

| Component | Responsibility |
| --- | --- |
| PhotoWallApp | App configuration and composition of shared services. |
| PhotoWallScreen | Lazy three-column grid, stable keys, scroll position, debug-panel access. |
| PhotoViewerScreen | Selected-photo display, back navigation, viewer request ownership. |
| PhotoImage | Stateful cell/viewer image widget; manages request generation and image lease; renders loading/error/ready state. |
| PhotoCatalog | At least 100 stable photo IDs and their HTTPS source URLs; no network calls from widget build methods. |
| ImageLoader | Coordinates memory lookup, disk/network source resolution, decoding, and subscriber delivery. |
| LoadScheduler | Three-slot limit, request priority, queued-request removal, and finally-block permit release. |
| MemoryImageCache | Decoded image LRU, byte accounting, eviction statistics, and cache-owned handles. |
| DiskImageCache | Stable file keys, index recovery, serialized file/index changes, budget enforcement. |
| ImageDecoder | Target-sized decoding with cleanup; replaceable implementation for optional Android integration. |
| CacheDiagnosticsScreen | Displays live counters while open and offers manual clearing. |
| MemoryPressureObserver | Registers/unregisters with WidgetsBinding and requests aggressive memory trimming. |

Use constructor injection for filesystem location, HTTP client, decoder, clock,
and budgets so tests can supply deterministic fakes. Flutter stateful widgets and
ValueNotifier/ChangeNotifier are sufficient initially; no global service locator
or state-management package is required.

Planned layout:

~~~text
lib/
  main.dart
  app/
    photo_wall_app.dart
  features/photos/
    models/
    screens/
    widgets/
  core/images/
    image_loader.dart
    load_scheduler.dart
    memory_image_cache.dart
    disk_image_cache.dart
    image_decoder.dart
    cache_diagnostics.dart
    memory_pressure_observer.dart
~~~

Create files as their features arrive. HTTP, path-location, and hashing utilities
may use packages selected for compatibility with the installed SDK; memory/disk
management and eviction remain project code.

## Constants and identities

| Setting | Initial policy |
| --- | --- |
| Memory cache budget | 32 * 1024 * 1024 bytes (32 MiB). |
| Disk cache budget | 100 * 1024 * 1024 bytes (100 MiB). |
| Active pipeline jobs | 3, shared by thumbnail and viewer requests. |
| Thumbnail target | Physical cell dimensions derived from layout and device pixel ratio; no upscaling. |
| Viewer target | Fit within physical viewport, with a proposed 4-megapixel output cap. |
| Network timeout | Implemented 30-second total attempt deadline; no infinite automatic retries. |
| Compressed response limit | Proposed 20 MiB per response, enforced while streaming even without Content-Length. |

Binary limits are the project's interpretation of the brief's approximate MB
values. Display MiB explicitly. Output-pixel and response limits are defensive
project choices and may be tuned after profiling with the selected image source.

Photo identity is independent of list index. Disk identity is a deterministic hash
of the canonical source URL and source-variant version; never use Dart hashCode as
a persistent filename. Memory/request identity additionally includes target
dimensions and decode policy/version. A full-screen decode cannot overwrite a
thumbnail entry for the same photo.

## Loading contract

The proposed conceptual API is load(request) returning a request handle with a
result future and an idempotent release method. A successful result provides an
image lease. Each consumer owns its own disposable image handle.

1. Check decoded memory synchronously and promote an LRU hit.
2. On a miss, attach to an identical in-flight request or enqueue a new job.
3. After acquiring a scheduler slot, recheck memory and look for valid disk bytes.
4. If absent, download the bounded compressed response asynchronously and attempt
   a safe disk commit.
5. Decode to the requested dimensions, then admit a thumbnail to the memory cache
   if it fits and the request is still eligible.
6. Deliver a separate lease to each current subscriber. Drop and dispose results
   with no remaining consumers.
7. Release permits, temporary buffers, codecs, and in-flight records on every
   success, cancellation, and error path.

Disk write failure must not prevent displaying already downloaded valid bytes.
A corrupt disk image is invalidated and may receive one network recovery attempt;
a second decode failure becomes a recoverable UI error, not a retry loop.

After Phase 4 integration, use the custom decoder and RawImage path for project
images, avoiding parallel retention by Flutter's default ImageProvider cache.
Phase 2 may temporarily use ordinary network image loading; that implementation
must be removed from the final custom path.

## Decoded image ownership and memory budget

Cache entries hold one owned ui.Image handle, estimated bytes, and LRU position.
For the selected conventional image pipeline, account width * height * 4 bytes
per decoded image as the RGBA estimate. This is not a measurement of GPU, codec,
allocator, or total process memory; document that limitation in diagnostics and
README.

A memory hit returns a cloned handle to the consumer. Clones share underlying
image data. Eviction disposes only the cache's handle; active consumers remain
valid until they release their own handles. This follows Flutter's
[Image.clone contract](https://api.flutter.dev/flutter/dart-ui/Image/clone.html).
Count an underlying entry once in cache bytes, not once per clone.

LRU operations:

- On get, move the entry to most recently used.
- On insert, resolve any existing entry safely and evict least-recently-used
  entries before admission until the new entry fits.
- Reject cache admission for an entry larger than the budget; an active consumer
  may temporarily own it, subject to decode-size limits.
- Maintain cachedBytes between zero and budget after every cache mutation.
- Count removals caused by capacity or memory-pressure eviction in evictionCount.
  Manual clears and replacements are separately identifiable, not disguised hits.

Full-screen decodes use the same scheduler and disk layer but are not retained
in the shared decoded cache. The viewer owns its decoded lease until the route
is no longer renderable. Grid images use bounded lazy construction without
keeping the entire catalog alive.

PhotoImage releases its previous handle only after the rendered image has been
replaced safely, and releases the final handle on disposal. RawImage does not own
disposal; see [RawImage](https://api.flutter.dev/flutter/widgets/RawImage-class.html).
Tests must cover replacement during a frame and disposal during a pending request.

The 32 MiB guarantee applies to cache-owned decoded entries. Live widgets,
in-flight decodes, compressed buffers, and native allocations can exceed that
amount in aggregate. Track live leases during tests and profile process memory
rather than claiming a total-process cap.

## Decoding policy

Use asynchronous codec APIs with target dimensions and preserve aspect ratio.
Prefer inspecting dimensions through ImageDescriptor before allocating the
requested output; do not decode full-resolution images merely to resize them in
a widget. Target dimensions constrain output but do not guarantee that a platform
codec avoids every temporary full-size allocation.

Dispose codecs, descriptors, and buffers according to their ownership contract,
including failure paths. Only a single static frame is required; animated image
playback is outside scope. Reject invalid dimensions and oversized responses
cleanly. Use constrained source variants to further reduce source decode cost.

Flutter's [codec API](https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html)
supports target dimensions and can fail asynchronously. Validate the chosen
descriptor/codec implementation against Flutter 3.29.2 during Phase 4.

## Disk persistence and recovery

Store files under a dedicated app-private cache directory, using a utility to
resolve its path. The operating system may remove cache files; treat missing
files as misses without requiring external-storage permissions.

Maintain a versioned index containing key, relative filename, actual byte length,
and last-access timestamp. Use LRU by recorded successful access, with a stable
key tie-breaker for deterministic tests. Persist access metadata in serialized
batches; a crash may lose recent recency updates but must not lose size correctness.

Serialize index/file mutations and protect reads from concurrent deletion.
Downloads may overlap, but commits and eviction decisions must not race.

- Download to a unique temporary file with a bounded stream.
- Validate response success and limits before admission.
- Evict before committing when needed; exclude files currently held for a read.
- If pinned files prevent admission, display via transient bytes and skip caching.
- Commit within the same directory through rename and then update the index.
- Do not assume replacing an existing destination by rename is portable on Windows;
  use an explicitly tested replacement/recovery strategy.
- Persist index changes through a temporary index and recoverable replacement.
- Remove failed temporary downloads in finally blocks.

The 100 MiB budget governs committed image payload bytes. Index overhead and up
to three bounded temporary downloads are additional disk usage and must be
documented. Diagnostics display committed payload bytes; temporary bytes may be
shown separately. At quiescence no abandoned temporary files should remain.

At startup, reconcile the index with actual files, delete abandoned temporary
files, discard invalid entries, and enforce the budget before serving normal
requests. Rebuild or reset a corrupt index; unknown payload files may be discarded.
Use actual file lengths rather than trusting stale index values. Disk hits open
successfully before being considered valid. Corrupt images are invalidated after
decode failure.

## Scheduler and stale requests

Each of three pipeline slots covers the entire disk/network/decode job. Network
and decode stages within a job are sequential, so their combined active count is
at most three. Do not use two independent three-slot pools that allow six active
heavy operations. Report stage counts separately.

Identical decoded-request keys share one job with subscriber reference tracking.
Different target sizes may share disk content through a URL-keyed source future;
waiting subscribers must not start an additional download for that source.
Avoid acquiring a second scheduler permit inside an already admitted job.

Prioritize the visible full-screen request, then visible grid requests, then any
optional near-visible work; FIFO within a priority. Do not prefetch in the initial
implementation. Remove queued work when no subscribers need it. Active transport
or native decode cancellation is optional; correctness never depends on it.

Each widget increments a request generation on photo/size change and disposal.
Before applying a completion, verify mounted state, identity, and generation.
A stale completion is released without setState. Release is idempotent and a
shared job continues while any subscriber still needs it. Errors always clear
in-flight records so an explicit retry can start fresh work.

## Memory pressure and cache clearing

Register a lifecycle-owned WidgetsBindingObserver and remove it on service
disposal. Flutter exposes the signal through
[didHaveMemoryPressure](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver/didHaveMemoryPressure.html).

On memory pressure:

1. Increment a memory-admission epoch and drop all cache-owned decoded entries.
2. Remove unneeded queued work; retain only current consumers.
3. Prevent work started before the signal from immediately refilling the cache.
   Such work may deliver to active consumers without cache admission.
4. Permit later demand-driven requests under the same hard budget.

Visible handles remain valid; zero cached bytes does not imply zero native image
memory. Do not delete disk content merely because memory is pressured.

For optional manual clearing, use a distinct disk/cache generation barrier.
Invalidate admissions from older jobs, serialize disk cleanup, and keep currently
displayed leases safe. Requests already in progress may finish for active viewers
but must not silently recreate cleared cache entries. New admissions resume after
the clear barrier completes. Show partial disk-delete failures honestly.

## Diagnostics and error states

Expose a snapshot with memoryCacheBytes, diskCacheBytes, memoryEvictionCount,
activeDownloads, activeDecodes, and optionally queuedJobs, cache hit counts, and
liveLeaseCount. Emit updates after completed accounting changes; coalesce UI
notifications rather than rebuilding on every downloaded chunk.

Counters must return to idle after failures and disposal. Show the two cache
limits and units beside usage. Ongoing work excludes queued requests. Do not label
cache bytes as device RAM consumption.

UI states are loading, ready, and failed with retry. Handle HTTP errors, timeout,
offline transport, invalid image data, missing disk files, full/unwritable storage,
and late completions. Avoid synchronous filesystem work in widget builds.

## Optional Android MethodChannel

Channel name: com.assignment.photowall/image.
Keep it distinct from application ID com.assignment.photo_wall.

| Method | Request | Response |
| --- | --- | --- |
| decodeDownsampled | path: String? or bytes: Uint8List?, maxWidth: int, maxHeight: int, format: String | width: int, height: int, bytes: Uint8List |
| getMemoryInfo | No parameters required | availMemBytes: int, totalMemBytes: int, thresholdBytes: int, lowMemory: bool |

Project contract: exactly one of path or bytes must be supplied, dimensions must
be positive, and unsupported formats return a structured PlatformException.
Returned bytes are compressed in the requested supported format, with dimensions
matching the decoded output. Start with PNG support.

Run native file/bitmap work off Android's main thread and release native resources.
Use the same three-job scheduler for the whole native-plus-Dart decode sequence.
If implemented, grid thumbnails invoke native downsampling after disk/network
source resolution; Dart still decodes returned compressed bytes into a drawable
image. Account for the extra copy and encoding work as a documented tradeoff.
Test invalid input, channel failures, dimensions, aspect ratio, and resource cleanup.
iOS is not required for this bonus.

## Requirement traceability and validation

| PRD IDs | Phase | Evidence |
| --- | --- | --- |
| P01-P03 | 2 | Catalog length/identity tests, grid/viewer widget tests, Android scrolling inspection. |
| P06-P07 | 3-4 | Temporary-directory restart tests; fake HTTP proves no download on valid disk hit; corrupt/missing file recovery and byte-cap tests. |
| P05, P07 | 4 | Deterministic LRU sequences, replacement/oversize tests, size-specific keys, shared-handle lifetime tests. |
| P10-P12 | 5 | Controlled futures prove three-slot maximum, deduplication, permit release on failure, out-of-order responses, disposal, and fresh retries. |
| P08-P09 | 6 | Simulated pressure, no stale cache readmission, repeated viewer disposal tests, Android memory profiling. |
| P04, O03 | 7 | Counter assertions under hit/miss/error/clear/eviction; clear-versus-download race tests. |
| P13-P15 | 1 and 8 | Analyzer and code review, complete README, release APK build and device smoke test. |
| O01-O02 | 5 if implemented | Shared-subscriber cancellation tests and unneeded-result disposal. |
| O04 | 9 if implemented | MethodChannel contract tests and Android native integration tests. |
| O05 | 10 | iOS host and ImageIO thumbnail channel; macOS compilation and iOS smoke test pending. |

Use fake network/clock/decoder dependencies for repeatable unit tests, real tiny
fixtures for codec tests, and temporary directories for persistence tests. Avoid
live public image endpoints in unit tests. Validate cache byte counters separately
from real memory observations.

Manual release scenarios: cold load of 100+ photos, warm revisit, process restart,
offline cached revisit, rapid end-to-end scrolling, repeated full-screen open/back,
memory pressure, and failed request retry. Record device, build mode, observed
jank and memory behavior, and limitations. A debug emulator result is not a
substitute for profile-mode performance evaluation.

## Delivery and current risks

Normally keep two or three commits per implementation phase; Phase 10 is a
single combined commit at the owner's request. Update docs with actual
decisions as implementation evolves. Phase 1 has two commits: the app foundation
and documentation, including the PRD/TRD baseline.

Phase 1 formatting, analysis, and startup test passed; the owner confirmed an
Android launch. Phase 2 implements gallery/viewer flows with temporary NetworkImage
loading and injectable providers for deterministic UI tests. Thumbnail sources are 400px square crops;
the viewer currently caps the longest side at 1600px (below the proposed 4 MP cap).

Phase 3 implements app-private compressed image files, URL-hash keys, an
access-based 100 MiB eviction policy, index recovery, and disk-first loading.
It currently buffers each response in memory up to 20 MiB before the serialized
file write. Streaming downloads, in-flight deduplication, and file-read pinning
from the proposed design above are pending. Phase 4 replaced the production
decoded-image path with a 32 MiB LRU cache.
Thumbnail images use 400px target decoding; widgets hold cloned image handles,
while full-screen images are not admitted to the shared decoded cache.
The legacy framework ImageProvider remains only as an injectable test path.

Phase 5 adds one three-slot scheduler around each disk/network/decode job.
Full-screen jobs have queue priority, identical decoded requests share work,
and queued jobs cancel when their last subscriber leaves. Active jobs complete
for any remaining subscribers; unneeded results are disposed. Phase 9 work
also closes active HTTP requests after their last subscriber leaves. Native
and Flutter decodes already underway may finish, but cancelled results are
disposed. Different source variants are not yet deduplicated together.

Phase 6 registers a WidgetsBindingObserver for memory pressure, clears
cache-owned decoded handles, and advances an admission epoch so earlier
work cannot refill the cache. Viewer images remain uncached and are disposed
after their route stops rendering. Tests cover active clone validity,
observer removal, stale admission, and repeated viewer exits.

Phase 7 adds a live diagnostics screen and manual clear action. The clear
barrier prevents older downloads and decodes from refilling the caches. A
30-second total network deadline and visible Retry label handle stalled and
failed requests. Phase 8 acceptance tests now cover cache priority across a
process-style restart and recovery from corrupt disk bytes with a real decoder.

An Android emulator is detected. Debug grid and viewer interaction was observed,
but physical-device performance verification remains unavailable. The
agent-session Gradle client fails before compilation when opening
its local daemon connection (`PipeImpl` / `Invalid argument: connect`).

The first Phase 8 cloud APK workflow succeeded and uploaded an artifact. That
build predates Phase 9 and has not been installed or smoke-tested. Phase 9 adds
Android MethodChannel methods, Dart response validation, and native downsampling
for thumbnails. The Phase 9 cloud APK compiled successfully, and the owner
smoke-tested it on an emulator. Physical-device profiling remains unavailable.

Phase 10 adds an iOS host and a Swift implementation of decodeDownsampled.
The Android-only getMemoryInfo method remains unavailable on iOS. A macOS build
and iOS device or simulator check are still needed.

Before submission, complete the required phases, resolve Android verification,
review release signing (currently the template's debug signing), and produce a
tested APK. Commit source and lockfile, exclude local SDK paths/secrets/build
outputs, and attach the APK separately. No GitHub push occurs until the owner has
reviewed the prepared local result and approved publishing.
