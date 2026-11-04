# Implementation plan

Each phase targets two or three cohesive commits. Relevant tests and documentation
travel with the behavior they describe. Validate and review each staged diff before
committing. Do not commit generated builds, local SDK paths, or signing secrets.

Use [the PRD](PRD.md) for scope and acceptance criteria and [the TRD](TRD.md)
for technical contracts and requirement-to-test mapping. Phase 1 includes the
PRD/TRD baseline in its documentation commit. Publish to GitHub only after owner approval.

## Phase 1 - Foundation

1. chore: initialize Photo Wall app foundation
2. docs: define requirements architecture and delivery plan

Complete: source and automated checks passed; the owner confirmed an Android
launch. Agent-session builds still encounter the loopback error noted in README.md.

## Phase 2 - Gallery and navigation

1. feat: add photo catalog and lazy three-column grid
2. feat: add fullscreen photo navigation and loading states
3. test: cover gallery navigation and error recovery

Acceptance: at least 100 remote images, lazy scrolling, full-screen navigation,
back navigation, and loading/error states. Basic loading is temporary scaffolding
until the custom pipeline replaces it.

Implemented: 100 distinct photos, lazy three-column grid, full-screen navigation,
scroll retention, loading/error states, and retry. Automated validation covers
catalog identity/sizing, grid layout, navigation, retries, stale completions, and
disposal during retry. All seven tests and static analysis pass; formatting is clean.
Phase 2 Android interaction/performance checks remain pending;
the agent-session APK build is blocked by the Gradle loopback error.

A separate UI checkpoint after Phase 2 adds the installed Forui 0.11.1 themes
and controls. Its light/dark and narrow-width behavior is covered by widget tests.

## Phase 3 - Disk cache

1. phase-3: persist bounded image files and cache metadata
2. phase-3: load photos from disk before network
3. phase-3: verify disk cache behavior and document tradeoffs

Acceptance: approximately 100 MB cap, safe file writes, predictable eviction,
restart recovery, and no repeat downloads on valid disk hits.

Implemented: URL-hashed files, persisted index, access-based eviction,
100 MiB payload cap, startup reconciliation, and disk-first image loading.
Tests cover restart hits, invalidation, eviction, corrupt metadata, and
serialized concurrent mutations. Android interaction/build verification
remains pending in the agent session.

## Phase 4 - Decoded memory cache

1. phase-4: add decoded image LRU cache with owned handles
2. phase-4: render gallery with bounded decoded image cache
3. phase-4: document memory ownership and verify integration

Acceptance: approximately 32 MB cache cap; memory then disk then network;
keys include identity and decode size; evicted images remain safe for active users.
Oversized images must not break the cache cap.

Implemented: decoded thumbnail LRU with a 32 MiB cap, cache-owned handles,
widget-owned clones, target-sized decoding, disk-then-network fallback,
and uncached viewer images. Tests cover LRU, oversized images, cache hits,
stale results, and disposal. Android verification remains pending.

## Phase 5 - Loading coordination

1. phase-5: bound image pipeline to three active jobs
2. phase-5: share image requests and cancel unused queued work
3. phase-5: verify loading races and document coordination

Acceptance: three active pipeline jobs at most, correct cell identity during fast
scrolling, no duplicate work for identical active requests, and graceful failures.

Implemented: a three-slot scheduler across disk/network/decode, urgent viewer
queue, identical-request sharing, queued cancellation, and widget generation
checks. Tests cover permit limits, priority, failures, shared subscribers,
and cancellation replacement races. Active transport cancellation and prefetch
remain optional and are not implemented.

## Phase 6 - Memory lifecycle

1. feat: trim decoded cache on memory pressure
2. fix: release fullscreen images and unused loading resources
3. test: verify pressure handling and viewer lifecycle

Acceptance: aggressive trimming on memory pressure, safe ownership/disposal,
and no accumulating full-screen images after repeated navigation.

## Phase 7 - Diagnostics and UX

1. feat: display cache usage evictions and active work
2. feat: add manual cache clearing and consistent retry controls
3. style: refine gallery and viewer presentation

Acceptance: accurate memory/disk bytes, eviction count, and active download/decode
counts; safe clearing while work is active; usable loading and failure states.

## Phase 8 - Submission readiness

1. test: add end-to-end gallery and cache acceptance coverage
2. docs: explain caching architecture tradeoffs and limitations
3. chore: prepare verified Android release build

Acceptance: required behavior verified, Android performance inspected, README
complete, working release APK smoke-tested, public repository and APK ready.
Keep artifacts out of source history; distribute the APK as a release attachment.

## Optional phase 9 - Native Android bonus

1. feat(android): add downsampled decoding MethodChannel
2. feat(android): expose memory information and integrate native decoding
3. test: validate native image decoding and channel failures

Use channel com.assignment.photowall/image with decodeDownsampled and
getMemoryInfo, following the assignment's request/response contract.
Only start after the required app is stable.
