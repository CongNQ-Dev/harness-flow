# Test Case Writer Prompt Template

Use this template when dispatching the Test Case Writer subagent — dispatched by `/aiflow-testgen` (standalone, or inside stage 5 of `/aiflow-review`).

**Purpose:** Produce the manual test-case deliverable a human QA tester executes (real device for the app, browser for admin, API calls for backend). This is not another code review — the reader is a tester, not an engineer.

```
Task tool (general-purpose):
  description: "Write manual test cases for <TICKET-ID>"
  prompt: |
    You are writing manual test steps for a human QA tester.
    The reader has NOT seen the code, the spec, or this conversation — write for them.

    Test surface per repo changed — read `workflow.yaml` `repos.<repo>.qa_surface`
    for each repo in scope and write one section per surface, in this order
    when several apply: `api` first, then `browser`, then `mobile-device` (so
    the tester verifies the data source before the screens that display it):
    - `qa_surface: mobile-device` → real device (iOS/Android), app flavor + account state
    - `qa_surface: browser` → browser, environment URL + role
    - `qa_surface: api` → a request the tester can run (GraphQL query or REST
      call with exact endpoint, headers, body, expected response fields) —
      plus, when the change is visible on a browser/device surface too, the
      end-to-end steps there
    - no `qa_surface` set for that repo → a generic "verify the change"
      section naming exactly what changed, not a tailored one
    [FULL LIST of repos in scope with their qa_surface value, from workflow.yaml —
    e.g. in this project: bump-mobile-app=mobile-device, bump-admin=browser,
    bump-backend=api]
    Cross-repo tickets MUST include one end-to-end scenario that goes through
    every changed repo (e.g. change a value on the browser surface → see it
    on the mobile-device surface).

    **Write the entire file in Japanese.** Screen names, button labels, and expected
    text should match what actually appears in the app's Japanese UI — don't translate
    UI strings independently, quote what the app actually shows.

    ## Ticket

    [FULL TEXT of docs/aiflow/<TICKET-ID>/ticket.md]

    ## Spec

    [FULL TEXT of docs/aiflow/<TICKET-ID>/spec.md]

    ## Plan (full route) — task list per repo

    [task headings + files from plan.md, or 'light route: see spec 実装タスク']

    ## What Was Implemented

    [Per repo: files changed, branch name, commit range — or 'not implemented yet' when run before stage 4]

    ## Your Job

    Write `docs/aiflow/<TICKET-ID>/test-cases.md` (in Japanese). Start it with this
    frontmatter, then the sections below:

    ---
    type: Test Cases
    ticket: <TICKET-ID>
    repos: [..]
    sources: [ticket.md, spec.md, plan.md]
    generated: {by: aiflow-testgen, at: YYYY-MM-DD}
    status: draft
    ---

    Number every case `TC-01`, `TC-02`, ... so QA can report results by ID
    (OK/NG column in a table per section).

    1. **前提条件 (Setup)** — exact starting state (environment URL, app version/flavor, account/data
       state, device state e.g. "already installed and logged in", "notification
       permission granted")
    2. **手順 (Numbered steps)** — one physical action per step ("ホーム画面の「再生」
       ボタンをタップする", not "再生できることを確認する"). Include exact screen names,
       button labels, and inputs, matching the app's actual Japanese UI text.
    3. **期待結果 (Expected result per step)** — what the tester should observe after
       each step, stated concretely enough that a pass/fail (OK/NG) is unambiguous.
    4. **リグレッション確認 (Regression checks)** — 1-2 steps confirming adjacent
       behavior the fix must NOT have broken (derived from the plan's file list across all repos —
       anything touched that wasn't the primary target of the bug).
    5. **不具合の再現確認 (Bug repro, if this is a bug fix)** — the original steps to
       reproduce from the ticket, translated into the same step format, so the tester
       can confirm the bug no longer happens, not just that a new feature works.

    Do not describe internals, code, or test names. Do not say "verify the fix" —
    say what to tap and what should appear, in Japanese.

    Report: file path written, and the number of numbered steps.
```
