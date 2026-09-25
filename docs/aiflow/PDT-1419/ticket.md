# BUMP Bug Ticket — Normalized: PDT-1419

### Basic Info

| Field | Value |
|-------|-------|
| **ID** | PDT-1419 |
| **Notion URL** | — |
| **Platform** | — |
| **Target** | Admin |
| **Status** | Task Pending |
| **Priority** | — |
| **Importance** | Small |
| **Type** | Bug |
| **Assignee** | 佐々木祐樹 (yuki-sasaki) |

---

### Title

> 【管理画面】全話無料キャンペーン新規作成画面にて初期状態でシーズン登録エリアが表示されている

*(Translation: [Admin] On the "All Episodes Free Campaign" new creation screen, the season registration area is displayed in the initial state)*

---

### Problem Summary

On the All Episodes Free Campaign new creation screen, the season registration area is visible by default when the page first loads. This is inconsistent with other similar screens such as the TOPICS creation screen (image URL / banner), where the area only appears after the user presses an Add button.

---

### Occurrence Conditions

| Field | Value |
|-------|-------|
| **User Segment** | — |
| **Billing Status** | N/A |
| **Platform Details** | — |
| **App Version** | — |
| **Device Model** | — |
| **OS Version** | — |
| **Environment** | Admin screen dev v8 |
| **Frequency** | Always |
| **A/B Test / Feature Flag** | — |

---

### Reproduction Steps

Preconditions:
- Logged into the admin screen

Steps:
1. On the All Episodes Free Campaign list screen, press the "New Create" button
2. On the new creation screen, scroll to the bottom of the page and observe

---

### Expected / Actual Behavior

| | Content |
|---|---|
| **Expected** | The season registration area should NOT be displayed in the initial state — it should only appear after the user presses an Add button (consistent with the TOPICS creation screen pattern for image URL / banner sections) |
| **Actual** | The season registration area is displayed immediately in the initial state, before any Add button is pressed |

---

### Acceptance Criteria

- [ ] On the All Episodes Free Campaign new creation screen, the season registration area is hidden on initial load
- [ ] Pressing the Add button causes the season registration area to appear (matching the TOPICS creation screen pattern)
- [ ] Regression check: existing campaign creation and editing flows are unaffected

---

### Impact

| Field | Value |
|-------|-------|
| **Screen / Feature** | All Episodes Free Campaign — new creation screen (Admin) |
| **Affected Users** | Admin operators |
| **Analytics Impact** | None |
| **Revenue / Billing Impact** | None |

---

### Related Resources

| Type | Value |
|------|-------|
| Figma | — |
| Related Tickets | — |
| Related PR | — |
| Screenshots | Yes (video of campaign list; ticket screenshots provided) |
| Comment Notes | — |

---

### Unknowns (for Brainstorming)

- [ ] Which component / file renders the season registration area on the All Episodes Free Campaign creation screen?
- [ ] Is the "show area only after Add button press" behavior already implemented for TOPICS (image URL / banner)? If so, can it be reused or referenced?
- [ ] Are there other screens with the same inconsistency that should be fixed at the same time?
