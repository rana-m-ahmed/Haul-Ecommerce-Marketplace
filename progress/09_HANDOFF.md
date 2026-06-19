# 09 - Handoff

## What changed on 2026-06-19

- Audited the current Firebase auth/storage/key wiring instead of assuming the earlier `Done` board status was accurate.
- Fixed a real runtime blocker in `app/lib/main.dart`: Flutter now calls `WidgetsFlutterBinding.ensureInitialized()` and `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before `runApp`.
- Removed non-generated `com.example` placeholder identifiers from:
  - `app/ios/Runner.xcodeproj/project.pbxproj`
  - `app/macos/Runner/Configs/AppInfo.xcconfig`
  - `app/macos/Runner.xcodeproj/project.pbxproj`
  - `app/windows/runner/Runner.rc`
  - `app/linux/CMakeLists.txt`
- Downgraded `Replace placeholders with real keys` on the task board from `Done` to `Blocked`, because `app/lib/firebase_options.dart` still has real platform-config blockers.

## What is true now that was not true before

- Android Flutter startup is no longer missing Firebase initialization, so real FirebaseAuth / Firestore-backed app flows can bootstrap correctly on supported platforms.
- The obvious shipped template IDs (`com.example.*`) are gone from the editable platform config files listed above.
- The remaining placeholder problem is narrowed to real missing platform Firebase registration, not stray template metadata.

## Verification completed

- `python -m pytest backend/app/tests -q`: `67 passed, 1 skipped`
- `D:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test`: `No issues found!`
- `D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\debug_router_test.dart test\flow_golden_test.dart`
  - `debug_router_test.dart`: passed
  - `flow_golden_test.dart`: 3 golden failures with about 20% pixel diffs on all home-flow screenshots
- Placeholder scan still reports:
  - unconfigured iOS/macOS/Windows/Linux branches in `app/lib/firebase_options.dart`
  - a web placeholder block in `app/lib/firebase_options.dart`

## Required next session

1. Decide whether to finish Firebase platform setup or intentionally scope Firebase support to Android-only for now.
2. If multi-platform support is required, register real Firebase apps for web and Apple platforms, add the missing config files/values, and regenerate `app/lib/firebase_options.dart`.
3. Investigate `BUG-013` by comparing `app/test/failures/` against `progress/screenshots/sprint2_flows/` to see whether the home-flow goldens changed because of a real UI regression or stale baselines.
4. Keep Sprint 6 checkout work in mind: `backend/app/services/checkout_service.py` still returns contract examples and does not use Stripe.
5. If a physical Android phone becomes available, continue the previously blocked camera/profile-memory acceptance run from the prior handoff.

## Open blockers

- `BUG-011`: Firebase is only truly configured for Android; `app/lib/firebase_options.dart` still contains unsupported placeholder branches for other platforms.
- `BUG-012`: Stripe checkout is not wired end-to-end yet; checkout service still returns contract examples.
- `BUG-013`: Flow goldens are currently failing on all three Sprint 2 home screenshots.
