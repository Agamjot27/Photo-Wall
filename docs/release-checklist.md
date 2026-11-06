# Android release verification

Use this checklist before publishing the APK. Record the Android device or emulator,
API level, Flutter version, build mode, date, and any visible frame stalls.

## Build and install

From the repository root:

~~~sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
~~~

The current release configuration uses the debug signing key. This produces an
installable APK for assignment review; do not use it as a store signing setup.
Keep the APK out of Git history and attach it to the GitHub release.
The Android APK GitHub Actions workflow runs the same checks on Ubuntu and
provides a downloadable APK artifact after a successful push or manual run.
Install and smoke-test that artifact before attaching it to a release.

## On-device acceptance

- [ ] Cold launch shows a three-column grid and photos load without blocking scroll.
- [ ] Scroll through all 100 entries; visible cells keep the correct photo.
- [ ] Open several photos, including one near the end; each viewer shows the
      selected image and both back paths return to the previous grid position.
- [ ] Reopen a recently viewed thumbnail and viewer; cache counters reflect usage.
- [ ] Restart the app, then revisit cached images while offline. Uncached images
      show Retry and recover when connectivity returns.
- [ ] Toggle the live grid panel; scroll while watching memory/disk bytes,
      evictions, active downloads, and active decodes. Open Details / clear and
      clear caches; visible images remain usable.
- [ ] Repeat viewer open/back several times and inspect memory in profile mode for
      continually retained viewer images or repeated frame-budget overruns.
- [x] Install and launch the final release APK on Android.

The optional iOS host is checked separately by the macOS simulator build
workflow. An iOS simulator or device smoke test is still required before claiming
iOS support as verified.

## Evidence so far

- Automated formatting, analysis, and 46 tests passed locally on 2026-11-06.
- A debug emulator displayed the grid and full-screen viewer after a hot restart.
- The Phase 8 baseline GitHub workflow succeeded and uploaded an APK artifact,
  but that artifact has not been installed or smoke-tested. It predates the
  native Android bonus.
- The Phase 9 release workflow passed. The owner installed its APK on an Android
  Studio emulator and confirmed gallery/viewer navigation, diagnostics, cache
  clearing, and reopening a cached photo after an offline app restart.
- The Phase 10 Android APK and iOS simulator builds passed. The owner has not
  installed the Phase 10 APK, and iOS runtime testing remains open.
- The v1.0.0 APK was built locally from commit `32178d9`, installed on an API 35
  emulator, and attached to the GitHub Release. The gallery scrolled to the last
  photo, which opened in the viewer. The APK hash matches the Release asset.
- Final GitHub Actions jobs did not start due to an account billing lock; this
  is not a test failure. Physical-device profile observations remain unavailable.
