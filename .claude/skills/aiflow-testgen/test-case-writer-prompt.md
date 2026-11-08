# Test Case Writer Prompt Template

Dispatched by `/aiflow-testgen` (standalone, or inside stage 5 of
`/aiflow-review`).

**Purpose:** the manual test-case deliverable a human tester executes. Not
another code review — the reader is a tester, not an engineer.

```
Task tool (general-purpose):
  description: "Write manual test cases for <TICKET-ID>"
  prompt: |
    You are writing manual test steps for a human tester.
    The reader has NOT seen the code, the spec, or this conversation — write for them.

    **Write the whole file in [LANGUAGE].** Screen names, button labels,
    messages and expected text must match what the product actually shows
    in that language — quote the real UI strings (you may read the UI source
    to find them), don't translate them yourself.

    ## Components in scope and how each is verified

    [For each affected component: name, qa_surface, and the environment the
    tester uses (URL / build / API base URL / install method) if known]

    Write one section per surface, in this order when several apply — the
    data source before whatever displays it: api → cli → library → browser
    → desktop → mobile-device.
    - `api` → a request the tester can send (curl or a GraphQL query): exact
      endpoint, headers, body, and the expected status + response fields.
    - `browser` → URL, role/account to log in with, clicks, what appears.
    - `mobile-device` → real iOS/Android device, build/flavor, account state,
      taps, what appears.
    - `desktop` → installed app + OS, what to click, what appears.
    - `cli` → exact commands to run and the expected output / exit code.
    - `library` → a minimal usage snippet the tester runs, and its expected
      result.
    - `none` → how to run the automated tests that prove it, and what "pass"
      looks like.
    - no qa_surface set → a generic "verify the change" section naming
      exactly what changed and what to observe.

    More than one component changed → you MUST also write one end-to-end
    case that goes through every changed component (e.g. change a value
    through the API → see it on the browser screen).

    ## Ticket
    [FULL TEXT of docs/aiflow/<TICKET-ID>/ticket.md]

    ## Spec
    [FULL TEXT of docs/aiflow/<TICKET-ID>/spec.md]

    ## Plan — tasks per component
    [task headings + files from plan.md, or "light route: see the spec's implementation tasks"]

    ## What was implemented
    [Per git root: files changed, branch, commit range — or "not implemented yet"]

    ## Your job

    Write `docs/aiflow/<TICKET-ID>/test-cases.md` in [LANGUAGE]. Start with:

    ---
    type: Test Cases
    ticket: <TICKET-ID>
    components: [..]
    sources: [ticket.md, spec.md, plan.md]
    generated: {by: aiflow-testgen, at: YYYY-MM-DD}
    status: draft
    ---

    Number every case `TC-01`, `TC-02`, ... so results can be reported by ID
    (an OK/NG column per section). Then, per section:

    1. **Setup** — exact starting state (environment, version/build, account
       or data state, device state).
    2. **Steps** — one physical action per step ("Click **Apply coupon**",
       not "verify coupons work"), with exact names and inputs.
    3. **Expected result per step** — concrete enough that OK/NG is unambiguous.
    4. **Regression checks** — 1–2 cases confirming adjacent behavior the
       change must not have broken (derived from the files the plan touched).
    5. **Bug repro** (bug tickets) — the ticket's original repro steps in the
       same format, so the tester confirms the bug is gone.

    No internals, code or test names. Never "verify the fix" — say what to do
    and what should appear.

    Report: the file path and the number of test cases.
```
