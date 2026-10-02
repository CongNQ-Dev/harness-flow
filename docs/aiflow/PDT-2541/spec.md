---
type: Spec
ticket: PDT-2541
kind: bug
route: light
components: [bump-mobile-app]
sources: [ticket.md, "bump-mobile-app/lib/legacy/screen/news_detail_page.dart", "bump-mobile-app/lib/presentation/components/mypage_web_view.dart"]
generated: {by: aiflow-spec, at: 2026-10-02}
status: approved
---

# Spec: PDT-2541 — 【Android】お知らせ詳細画面のフォントサイズが大きい

## Root cause

- `bump-mobile-app/lib/legacy/screen/news_detail_page.dart:67–71` — The `AndroidWebViewController` setup block calls `setMediaPlaybackRequiresUserGesture(false)` and `enableDebugging(true)` but never calls `setTextZoom(100)`. Android WebView inherits the device's system font scale factor (via `WebSettings.textZoom`), causing all web content text to render larger than the designer intended. iOS's WKWebView does not apply this scaling, which is why the bug is Android-only.

  Reference: `mypage_web_view.dart:252–256` has the same `AndroidWebViewController` block and is also missing `setTextZoom(100)` — but its symptoms are not reported broken, so it is out of scope here.

## Approach

Add a single call to `setTextZoom(100)` inside the `AndroidWebViewController` block in `_NewsDetailPageState.initState()`. This explicitly pins the WebView text zoom to 100%, overriding the device's system font scale and making text render at the CSS-specified size — matching iOS behavior.

`webview_flutter_android 4.10.9` (in use) exposes `AndroidWebViewController.setTextZoom(int textZoom)` at `lib/src/android_webview_controller.dart:678` — confirmed available, no API-compatibility concerns.

### Alternatives considered

| Option | Why not |
|---|---|
| n/a | Light route — no dialogue |

## Changes per component

### bump-mobile-app

- Files: `lib/legacy/screen/news_detail_page.dart`
- Change: Add `.setTextZoom(100)` to the `AndroidWebViewController` block in `initState()`, after the existing `setMediaPlaybackRequiresUserGesture(false)` call at line 70

## Contracts between components

n/a — no API, schema, or generated client changes.

## Behavior

| Condition | Before | After |
|---|---|---|
| Android: open notification detail screen | Text rendered too large (WebView inherits system font scale) | Text rendered at 100% zoom (CSS-specified size) |
| iOS: open notification detail screen | Normal (WKWebView unaffected) | No change |
| Android: OS font size accessibility setting changed | Inconsistent (WebView partially follows system scale) | Unaffected — `setTextZoom(100)` is fixed regardless of OS setting |

## Acceptance criteria

- [ ] The notification detail screen displays text at the same perceived size on Android as on iOS
- [ ] The fix does not affect text size when the OS font size accessibility setting is changed
- [ ] Other WebView screens (e.g. `MyPageWebView`) are unaffected by this change
- [ ] The screen continues to load and display notification content correctly on both platforms

## Out of scope

- `mypage_web_view.dart` — also missing `setTextZoom(100)` but not reported broken; should be a separate ticket if needed
- Server-side HTML/CSS font-size changes — the fix is client-side only

## Implementation tasks

### Task 1: Pin Android WebView text zoom in NewsDetailPage (component: bump-mobile-app)

- Files: `lib/legacy/screen/news_detail_page.dart`
- Change: In `initState()`, inside the `if (controller.platform is AndroidWebViewController)` block (lines 67–71), add:
  ```dart
  (controller.platform as AndroidWebViewController).setTextZoom(100);
  ```
  after the `setMediaPlaybackRequiresUserGesture(false)` call.
- Test: Manual on an Android device/emulator — open the notification detail screen and confirm text is no longer disproportionately large. No unit test applicable (WebView rendering is not unit-testable).
- [x] Done
