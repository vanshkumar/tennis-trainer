---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 1
total_count: 2
last_updated: 2026-09-26T15:11:59.755Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | lint-warning | Tennis TrainerTests/BallDetectionManagerTests.swift |  | Controlled semaphore-stall tests emit a Thread Performance Checker priority warning; no production timing inference. | open |  | 2026-09-26T04:30:36.746Z |  |
| 2 | 02 | stub | Tennis Trainer/ContentView.swift | 209 | Inherited Request Permission action is empty; scheduled for plan 02-02. | fixed |  | 2026-09-26T14:59:53.671Z | 2026-09-26T15:11:59.755Z |

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
  }
]
````
