# Photo Wall Product Requirements Document

Version: 1.0
Date: 2026-11-04
Status: Implementation baseline; features are planned unless explicitly marked complete.
Repository: [Agamjot27/Photo-Wall](https://github.com/Agamjot27/Photo-Wall)

## Purpose and source

Build an Android Flutter app that displays a remote photo collection while
demonstrating correct custom caching, memory management, concurrency, and readable
engineering decisions.

The source of mandatory requirements is the supplied five-page "Flutter Take-Home
Assignment - Photo Wall" PDF. This PRD summarizes that brief; the assignment remains
the authority if a discrepancy is found. Engineering decisions are specified in
[the TRD](TRD.md), and delivery is tracked in [the phase plan](implementation-plan.md).

## Users and success criteria

The app serves a person browsing photos and an evaluator inspecting behavior under
scrolling, memory pressure, network failure, and repeated navigation.

Success means every mandatory requirement below passes its acceptance checks,
a working Android APK is provided with the public source repository, and the
developer can explain the implementation and tradeoffs. Visual polish is secondary
to correctness and understanding.

## Scope

Required scope includes the grid, full-screen viewer, custom memory and disk
caches, bounded loading, memory-pressure response, diagnostic panel, README, and APK.

Project choices beyond the brief include preserving scroll position on return,
explicit retry controls, stable photo identities, exact binary cache limits, and
a three-job scheduler. These choices support the requirements but are not presented
as additional assignment mandates.

Accounts, uploads, editing, favorites, search, a backend, and store publication
are out of scope. iOS is optional; the initial implementation targets Android.

## User flows

1. Open the app and see a three-column grid. Each image independently transitions
   from placeholder to photo or a recoverable error state.
2. Scroll through at least 100 distinct remote photos. Cells keep their correct
   identity even when responses arrive out of order.
3. Tap a photo to view it full-screen. Use the visible back control or Android
   back navigation to return to the previous grid position.
4. Revisit previously loaded photos. Use memory or disk when available; cached
   content remains usable without a network connection.
5. Open the debug panel and inspect cache usage, evictions, and active work.
   The panel may be toggleable and must remain accessible.

Offline access is limited to cached variants. A cached thumbnail does not promise
that a separate full-screen network variant is available offline.

## Mandatory requirements and acceptance criteria

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| P01 | Remote photo grid | At least 100 distinct remote photo entries; exactly three columns; lazy cell construction. |
| P02 | Smooth, responsive browsing | Scroll and tap remain responsive during loading. Profile on an Android device, record device/build details, and investigate repeated frame-budget overruns. The brief does not specify a numeric FPS target. |
| P03 | Full-screen viewer | Tapping a photo opens that photo full-screen; back navigation returns to the grid. Project choice: retain the scroll offset. |
| P04 | Debug panel | Display decoded memory-cache bytes, disk-cache bytes, cumulative memory-cache eviction count, and ongoing downloads/decodes. Clearly label units and distinguish active from queued work if both are shown. |
| P05 | Custom decoded memory cache | Implement byte accounting and eviction internally, with an approximately 32 MB hard cache budget. Tests prove eviction and that cached bytes never exceed the configured limit after a cache operation. |
| P06 | Custom disk cache | Persist downloaded files under app storage, enforce an approximately 100 MB limit, and evict older entries. Restarting the app preserves valid cached files and their discoverability. |
| P07 | Loading priority | Thumbnail lookup follows memory, then disk, then network. A valid disk hit does not issue an HTTP image download. Decoded images are not retained indefinitely. |
| P08 | Memory pressure | Handle Flutter memory-pressure notifications through WidgetsBindingObserver and aggressively trim decoded cache ownership. Visible images remain safe to render. |
| P09 | Viewer memory lifecycle | Repeated viewer open/close cycles release viewer-specific decoded images. Profiling must not show continually increasing retained viewer images. |
| P10 | Bounded concurrent work | Simultaneous downloads/decodes are limited to a chosen value in the assignment's 2-4 range. Project choice: at most three active pipeline jobs, with no more than three active downloads plus decodes combined. |
| P11 | Stale-result correctness | A late result cannot replace the image requested by a newer cell request or update a disposed widget; discarded results release their resources. |
| P12 | Failure handling | Network and decode failures do not crash the app or block other photos. Project choice: a per-image retry action and an understandable failure state. |
| P13 | Maintainable code | Separate UI, loading, and cache logic; use meaningful names and appropriate error handling without unnecessary architecture. Cache policies are implemented by this project, not delegated to a complete image-caching package. |
| P14 | README | Explain running, architecture, memory/disk cache implementations and eviction, pressure handling, native integration if present, tradeoffs, limitations, and incomplete features. |
| P15 | Submission | Public GitHub repository with complete source, README, a working Android APK, and implementation notes. Publishing is a separate action performed after the owner's push approval. |

## Optional enhancements

| ID | Enhancement | Scope |
| --- | --- | --- |
| O01 | Request cancellation | Cancel no-longer-needed downloads where feasible; required stale-result ignoring does not depend on cancellation. |
| O02 | Decode cancellation | Cancel pending decode work; if a native decode cannot stop, discard its result safely. |
| O03 | Manual cache clear | Clear cached content safely during active work. Planned for Phase 7, but optional in the assignment. |
| O04 | Android native integration | Implement decodeDownsampled and getMemoryInfo over the specified MethodChannel, then use native decoding for grid thumbnails. |
| O05 | iOS integration | Additional bonus only; not currently scheduled. |

Optional features cannot displace mandatory correctness or submission work.

## Product behavior decisions

- Use stable public HTTPS image URLs with no embedded credentials.
- Keep the gallery usable while individual photos fail.
- Preserve aspect ratio; use crop-to-fill for thumbnails and fit-within-screen
  for the full-screen viewer.
- Use standard accessible controls, descriptive image semantics where metadata is
  available, and readable loading/error states. These are project quality choices.
- Do not add a permission prompt for app-private cache storage.
- Show cache counters as cache accounting, not as total Android process memory.

## Verification and delivery

Automated checks cover cache budgets, eviction order, persistence, out-of-order
requests, concurrency limits, and widget navigation/error behavior. Android
manual checks cover cold/warm loading, offline revisits, rapid scrolling, repeated
viewer navigation, pressure handling, and diagnostic accuracy.

Each phase has two or three cohesive commits. Phase 1 has two commits:
the app foundation and documentation, including the PRD/TRD baseline.
The complete phase mapping and test coverage are in the TRD.

The final release must pass formatting, analysis, relevant tests, APK build, and
device smoke testing. Attach the APK as a release artifact rather than committing
build output. Update README with observed evidence and remaining limitations.

## Current implementation state

Phases 1-3 provide the Android app foundation, a 100-photo gallery,
full-screen viewer, loading and retry states, and a custom compressed-image
disk cache. The cache persists across restarts, checks disk before network,
and enforces a 100 MiB committed-payload budget with access-based eviction.
Automated tests cover disk hits, restart recovery, and eviction. The owner
confirmed the Phase 1 Android launch and Phase 2 scroll/viewer behavior.

The custom decoded memory cache, bounded concurrency, memory lifecycle
handling, diagnostics, and native bonuses remain planned. Phase 3 device
interaction and performance checks are pending; the agent-session APK build
has previously encountered a Gradle loopback connection error. No Android
release or performance acceptance is claimed yet.
