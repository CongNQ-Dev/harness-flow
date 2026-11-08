# plan.md template (output of stage 3)

Written in `workflow.yaml` `language:` (translate the labels when that isn't
`en`); code, commands, paths and identifiers exactly as typed.
`/aiflow-impl` parses each `### Task N:` heading and its `**Component:**` /
`**TDD:**` lines — keep those two labels' positions and values machine-plain
(the label word may be translated; the value is a component name / `true` /
`false`).

The example below is illustrative (an API + web project); use your own
components, paths and commands from `workflow.yaml`.

````markdown
---
type: Plan
ticket: <TICKET-ID>
components: [api, web]
branch: bug/<TICKET-ID>/<slug>
sources: [spec.md]
generated: {by: aiflow-plan, at: YYYY-MM-DD}
status: draft                  # draft → approved at the stage 3 gate
---

# <TICKET-ID> implementation plan — <feature/fix name>

> **For agents:** `/aiflow-impl` runs one implementer subagent per task,
> then a spec-compliance review, then a quality review. Track progress with
> the checkboxes (`- [ ]`).

**Goal:** <one sentence>
**Branch:** `bug/<TICKET-ID>/<slug>` (created in stage 1)
**Architecture:** <2–3 sentences>
**Order:** api (task 1) → web (tasks 2–3: regenerate the client, then the UI change)

---

### Task 1: <unit name>

**Component:** api
**TDD:** true            <!-- false → one line saying why -->
**Files:**
- Modify: `src/orders/total.ts:40-58`
- Test: `src/orders/total.test.ts`

- [ ] **Step 1: write the failing test**

```ts
it("applies every coupon to the total", () => { /* real code */ });
```

- [ ] **Step 2: run it and watch it fail**

Run: `pnpm test -- src/orders/total.test.ts`
Expected: FAIL — "expected 80, received 90"

- [ ] **Step 3: write the minimal implementation**

```ts
/* real code */
```

- [ ] **Step 4: run it and watch it pass**

Run: `pnpm test -- src/orders/total.test.ts`
Expected: PASS

- [ ] **Step 5: commit**

```bash
git -C <git root> add src/orders/total.ts src/orders/total.test.ts
git -C <git root> commit -m "fix(<TICKET-ID>): apply all coupons to the order total"
```

### Task 2: regenerate the web client

**Component:** web
**TDD:** false (generated code only — verified by type-check and the existing tests)
...
````
