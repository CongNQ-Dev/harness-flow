---
type: Ticket
ticket: PDT-2541
kind: bug
title: "【Android】お知らせ詳細画面のフォントサイズが大きい"
components: [bump-mobile-app]
source: paste
generated: {by: aiflow-spec, at: 2026-10-02}
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
- [ ] Other WebView screens are unaffected by this change

## Impact

| | |
|---|---|
| Screens / features / endpoints | お知らせ詳細画面 (NewsDetailPage) |
| Users affected | All Android users |
| Data / money / security impact | no |

## Related

| | |
|---|---|
| Designs | — |
| Related tickets | — |
| Related PRs/MRs | — |
| Screenshots / recordings | yes (screen-20260812-100225-1786496533458.mp4) |
| Notable comments | — |

## Open questions

none

## AI assessment (outside the ticket — analysis is allowed here)

### Affected components

| Component | Verdict | Evidence (graph node / file:line / contract) |
|---|---|---|
| bump-mobile-app | affected | `lib/legacy/screen/news_detail_page.dart:67–71` — Android WebView init block missing `setTextZoom(100)` |
| bump-backend | not affected | Pure UI rendering issue; no API or data change involved |
| bump-admin | not affected | Admin console is web-only; no mobile WebView code |

### Triage

| Check | Result | Evidence |
|---|---|---|
| One component only | ✅ | Only `bump-mobile-app` |
| Expected files changed ≤ 3 | ✅ | 1 file: `lib/legacy/screen/news_detail_page.dart` |
| No API / schema / migration / contract change | ✅ | Client-side WebView setting only |
| Root cause located (file:line) | ✅ | `news_detail_page.dart:67–71` — Android block missing `setTextZoom(100)` |
| Kind is bug | ✅ | Broken behavior on Android since past versions |
| No sensitive area touched | ✅ | No Firebase auth, DB migrations, or GraphQL schema involved |

**Recommended route:** `light` (1→2→4→6)
**Confirmed route:** `light` (1→2→4→6)
