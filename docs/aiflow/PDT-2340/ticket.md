---
type: Ticket
ticket: PDT-2340
kind: bug
title: "【iOS/Android】シェアボタンの連続タップでOSのシェアシートが複数表示される端末がある"
components: [bump-mobile-app]
source: paste
generated: {by: aiflow-spec, at: 2026-10-01}
status: draft
---

# PDT-2340 — 【iOS/Android】シェアボタンの連続タップでOSのシェアシートが複数表示される端末がある

## Basic info

| Field | Value |
|---|---|
| ID | PDT-2340 |
| Link | — |
| Type (from the ticket) | Bug (broken behavior with repro steps — multiple share sheets appear) |
| Status | — |
| Priority / severity | — |
| Assignee | — |
| Platform / environment | iOS & Android |
| Component (as the ticket states it) | 作品詳細 シェアボタン |

## Summary

作品詳細画面のシェアボタンを素早く連続タップすると、OSのシェアシートが複数枚表示される端末がある。発生端末は Android OS 16（Pixel 9a）および iOS OS 26.2（iPhone 13 mini）で確認済み。

## Conditions

| Condition | Value |
|---|---|
| Who is affected | All users |
| Environment | — |
| Version / build | — |
| Device / OS / browser | 発生: Android OS 16 (Pixel 9a), iOS OS 26.2 (iPhone 13 mini) / 非発生: iOS OS 18.6.2 (iPhone 16 Plus), iOS OS 26.5 (iPhone 14 Pro) |
| Frequency | 素早く連続タップしたとき |
| Feature flag / experiment | — |

## Steps to reproduce

Preconditions:
- 作品詳細画面を開いている

Steps:
1. シェアボタンを素早く複数回押下する

## Expected / actual

| | |
|---|---|
| **Expected** | OSのシェアシートが1枚だけ表示される |
| **Actual** | OSのシェアシートが複数枚表示される端末がある |

## Acceptance criteria

- [ ] シェアボタンを素早く連続タップしても、OSのシェアシートは1枚しか表示されない
- [ ] 通常の1回タップでシェアシートが正常に表示される（リグレッションなし）
- [ ] iOS・Android 両プラットフォームで動作する

## Impact

| | |
|---|---|
| Screens / features / endpoints | 作品詳細 シェアボタン |
| Users affected | All users on affected OS versions |
| Data / money / security impact | no |

## Related

| | |
|---|---|
| Designs | — |
| Related tickets | — |
| Related PRs/MRs | — |
| Screenshots / recordings | yes (PXL_20260601_095346966.mp4) |
| Notable comments | — |

## Open questions

none

## AI assessment (outside the ticket — analysis is allowed here)

### Affected components

| Component | Verdict | Evidence |
|---|---|---|
| bump-mobile-app | affected | `work_detail_page.dart:924-925` — share callback passed without `guardedTap` throttle; `usePreventMultiTap` hook instantiated at line 76 but not applied to share |
| bump-backend | not affected | Share is a purely client-side operation; no API call involved |
| bump-admin | not affected | Admin console has no share button |

### Triage

| Check | Result | Evidence |
|---|---|---|
| One component only | ✅ | bump-mobile-app only |
| Expected files changed ≤ 3 | ✅ | 1 file: `lib/presentation/work_detail/work_detail_page.dart` |
| No API / schema / migration / contract change | ✅ | Pure UI fix, no backend or contract change |
| Root cause located (file:line) | ✅ | `work_detail_page.dart:924-925` — missing `guardedTap` wrap |
| Kind is bug | ✅ | Broken behavior with repro steps |
| No sensitive area touched | ✅ | Share is not payments / auth / DB |

**Recommended route:** `light` (1→2→4→6)
**Confirmed route:** (filled in after the user confirms)
