---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 1
total_count: 4
last_updated: 2026-09-26T15:44:12.156Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | lint-warning | Tennis TrainerTests/BallDetectionManagerTests.swift |  | Controlled semaphore-stall tests emit a Thread Performance Checker priority warning; no production timing inference. | open |  | 2026-09-26T04:30:36.746Z |  |
| 2 | 02 | stub | Tennis Trainer/ContentView.swift | 209 | Inherited Request Permission action is empty; scheduled for plan 02-02. | fixed |  | 2026-09-26T14:59:53.671Z | 2026-09-26T15:11:59.755Z |
| 3 | 02 | unrun-verify | .planning/phases/02-dependable-practice-controls/02-02-PLAN.md |  | Physical camera permission request, Settings grant/revoke return, and supported restriction checks remain pending; user deferred to end of Phase 2. | open |  | 2026-09-26T15:44:12.034Z |  |
| 4 | 02 | unrun-verify | .planning/phases/02-dependable-practice-controls/02-02-PLAN.md |  | Physical camera startup, Stop, interruption and return/retry checks remain pending; injected events are not hardware evidence. | open |  | 2026-09-26T15:44:12.156Z |  |

````json
[
  {
    "id": 1,
    "kind": "lint-warning",
    "phase": "01",
    "file": "Tennis TrainerTests/BallDetectionManagerTests.swift",
    "line": null,
    "description": "Controlled semaphore-stall tests emit a Thread Performance Checker priority warning; no production timing inference.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-26T04:30:36.746Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 2,
    "kind": "stub",
    "phase": "02",
    "file": "Tennis Trainer/ContentView.swift",
    "line": 209,
    "description": "Inherited Request Permission action is empty; scheduled for plan 02-02.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-26T14:59:53.671Z",
    "resolved_at": "2026-09-26T15:11:59.755Z",
    "milestone": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "02",
    "file": ".planning/phases/02-dependable-practice-controls/02-02-PLAN.md",
    "line": null,
    "description": "Physical camera permission request, Settings grant/revoke return, and supported restriction checks remain pending; user deferred to end of Phase 2.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-26T15:44:12.034Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "02",
    "file": ".planning/phases/02-dependable-practice-controls/02-02-PLAN.md",
    "line": null,
    "description": "Physical camera startup, Stop, interruption and return/retry checks remain pending; injected events are not hardware evidence.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-26T15:44:12.156Z",
    "resolved_at": null,
    "milestone": null
  }
]
````
