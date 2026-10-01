# Task 1 Review — PDT-2541: Pin Android WebView Text Zoom in NewsDetailPage

**Component:** bump-mobile-app
**File reviewed:** `lib/legacy/screen/news_detail_page.dart`
**Commit:** `5a3268e`
**Branch:** `bug/PDT-2541/fix_news_detail_font_size_android`

---

## Spec Compliance

✅ **Spec compliant**

The diff confirms exactly one line was added at `lib/legacy/screen/news_detail_page.dart` line 71:

```dart
(controller.platform as AndroidWebViewController).setTextZoom(100);
```

This line sits immediately after the `setMediaPlaybackRequiresUserGesture(false)` call, inside the `if (controller.platform is AndroidWebViewController)` block in `initState()` — precisely where the spec required it.

**Acceptance criteria verification:**

- ✅ Text is pinned to 100% zoom on Android, which prevents the OS accessibility font scale from inflating WebView text — directly addressing the perceived size mismatch between Android and iOS.
- ✅ Setting `textZoom` to 100 unconditionally ignores the OS font-size setting for this WebView, which is the intended behavior (matching iOS rendering, which does not honor Android font scale).
- ✅ The change is scoped to `NewsDetailPage` only. No other WebView screen (`MyPageWebView`, `AnnounceDetailPage`, `web_contents_page.dart`, etc.) is touched.
- ✅ The call is placed after controller configuration and before the widget is built; the screen will continue to load and display content correctly on both platforms.

---

## Code Quality

### Strengths

- **Pattern consistency.** The added line follows the exact style used for `setMediaPlaybackRequiresUserGesture(false)` on the line directly above: same cast form, same indentation, same trailing semicolon. It reads as if it was always meant to be there.
- **Minimal scope.** One file, one line, zero refactoring. No unrelated changes were introduced.
- **Correct guard.** The call is correctly placed inside the `if (controller.platform is AndroidWebViewController)` block, so the cast is safe and iOS is unaffected.

### Critical (must fix)

None.

### Important (should fix)

None.

### Minor (nice to have)

- **MyPageWebView does not have `setTextZoom(100)`.**
  `lib/presentation/components/mypage_web_view.dart` has an identical Android block (lines 252–277) that calls `setMediaPlaybackRequiresUserGesture(false)` and `setOnShowFileSelector`, but does not pin text zoom. If `MyPageWebView` renders text content from the same web origin, users with a large OS font setting will see the same inflation bug there. This is a recommendation for a follow-up ticket — it is not a blocker for this fix.

- **`AnnounceDetailPage` uses an inline HTML string with an explicit `font-size: 34px` style** (`lib/presentation/announce/announce_detail_page.dart` line 30). That screen is immune to the Android text-zoom bug because the font size is hard-coded in HTML; no change needed there.

---

## Assessment

**Ready for delivery?** Yes

**Reasoning:** The implementation is exactly what the spec described — one line, correct placement, correct cast, no side effects. The only follow-up worth noting (`MyPageWebView` text zoom parity) is a separate concern that does not block this fix.
