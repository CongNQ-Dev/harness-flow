---
type: Ticket
ticket: PDT-2541
kind: bug
title: "【Android】お知らせ詳細画面のフォントサイズが大きい"
components: [bump-mobile-app]
source: paste
generated: {by: aiflow-spec, at: 2026-10-01}
status: approved
---

# PDT-2541 — 【Android】お知らせ詳細画面のフォントサイズが大きい

## Basic info

| Field | Value |
|---|---|
| ID | PDT-2541 |
| Link | — |
| Type (from the ticket) | Bug (describes broken behavior with repro steps and expected vs actual) |
| Status | — |
| Priority / severity | — |
| Assignee | — |
| Platform / environment | Android only (iOS unaffected) · stage / prod |
| Component (as the ticket states it) | お知らせ詳細画面 (notification detail screen) |

## Summary

On Android, the notification detail screen (`NewsDetailPage`) displays text at an excessively large font size. The issue is not dependent on the OS font size accessibility setting and has been present since past versions.

## Conditions

| Condition | Value |
|---|---|
| Who is affected | All Android users who view the notification detail screen |
| Environment | staging and production |
| Version / build | 4.13.0 (confirmed; present since earlier versions) |
| Device / OS | Android (all versions; iOS is unaffected) |
| Frequency | Always — reproducible on any Android device |
| Feature flag / experiment | — |

## Steps to reproduce

Preconditions:
- At least one notification (お知らせ) has been received

Steps:
1. Open the notification detail screen (お知らせ詳細画面)

## Expected / actual

| | |
|---|---|
| **Expected** | Notification detail text is displayed at a normal, readable font size (consistent with iOS) |
| **Actual** | Text is displayed too large on Android, regardless of OS font size setting |

## Acceptance criteria

- [ ] The notification detail screen displays text at the same perceived size on Android as on iOS
- [ ] The fix does not affect text size when the OS font size accessibility setting is changed (behavior remains consistent)
- [ ] Other WebView screens (e.g. MyPageWebView) are unaffected by this change
- [ ] The screen continues to load and display notification content correctly on both platforms

## Impact

| | |
|---|---|
| Screens / features / endpoints | お知らせ詳細画面 (`NewsDetailPage`) |
| Users affected | All Android users |
| Data / money / security impact | No |

## Related

| | |
|---|---|
| Designs | — |
| Related tickets | — |
| Related PRs/MRs | — |
| Screenshots / recordings | Yes (screen-20260812-100225-1786496533458.mp4) |
| Notable comments | — |

## Open questions

none

## AI assessment (outside the ticket — analysis is allowed here)

### Affected components

| Component | Verdict | Evidence |
|---|---|---|
| bump-mobile-app | affected | `NewsDetailPage` in `lib/legacy/screen/news_detail_page.dart` uses `AndroidWebViewController` without `setTextZoom(100)` — Android WebView inherits system font scale |
| bump-backend | not affected | News content is served via URL loaded in WebView; this is a client-side rendering issue |
| bump-admin | not affected | Admin console is unrelated |

### Triage

| Check | Result | Evidence |
|---|---|---|
| One component only | ✅ | Only `bump-mobile-app/lib/legacy/screen/news_detail_page.dart` changes |
| Expected files changed ≤ 3 | ✅ | 1 file: `news_detail_page.dart` |
| No API / schema / migration / contract change | ✅ | Pure client-side Flutter fix |
| Root cause located (file:line) | ✅ | `news_detail_page.dart:67–71` — `AndroidWebViewController` block missing `setTextZoom(100)` |
| Kind is bug | ✅ | Describes broken behavior; iOS works correctly |
| No sensitive area touched | ✅ | Notification display; no payments, auth, or DB migration |

**Recommended route:** `light` (1→2→4→6)
**Confirmed route:** `light`
