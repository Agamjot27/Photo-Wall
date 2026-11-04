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

Source and automated checks are complete. Android build and device-launch
verification remain blocked as recorded in README.md.

## Phase 2 - Gallery and navigation

1. feat: add photo catalog and lazy three-column grid
2. feat: add fullscreen photo navigation and loading states
3. test: cover gallery navigation and error recovery

Acceptance: at least 100 remote images, lazy scrolling, full-screen navigation,
back navigation, and loading/error states. Basic loading is temporary scaffolding
until the custom pipeline replaces it.

## Phase 3 - Disk cache

1. feat: persist downloaded images with cache metadata
2. feat: enforce disk budget and recover invalid entries
3. test: verify disk cache persistence and eviction

Acceptance: approximately 100 MB cap, safe file writes, predictable eviction,
restart recovery, and no repeat downloads on valid disk hits.

## Phase 4 - Decoded memory cache

1. feat: add byte-accounted decoded image LRU cache
2. feat: integrate thumbnail decoding and cache lookup priority
3. test: verify memory budget eviction and image ownership

Acceptance: approximately 32 MB cache cap; memory then disk then network;
keys include identity and decode size; evicted images remain safe for active users.
Oversized images must not break the cache cap.

## Phase 5 - Loading coordination

1. feat: bound image loading concurrency and share duplicate requests
2. fix: ignore stale image results and prioritize visible requests
3. test: cover loading races failures and concurrency limits

Acceptance: three active pipeline jobs at most, correct cell identity during fast
scrolling, no duplicate work for identical active requests, and graceful failures.

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
