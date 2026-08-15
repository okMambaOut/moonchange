# Originality and Ecosystem Position

MoonChange is an original repository change-governance project. Its central
workflow is policy evaluation over structured change metadata: route owners,
reconcile approval/check/label evidence, enforce budgets and forbidden
operations, and generate a review gate and plan.

It was deliberately designed after MoonPatch was rejected for overlapping the
mature MoonBit packages `mizchi/bit_apply@0.46.4` and
`mizchi/bit_diff_core@0.46.4`. MoonChange does not rename or wrap MoonPatch's
implementation. No MoonPatch source or history is present in this repository.

## Capability Boundary

| Capability | Provider |
| --- | --- |
| Parse Git unified diff into file metadata | `mizchi/bit_apply@0.46.4` |
| Diff algorithms and unified hunk generation | Not implemented by MoonChange |
| Patch apply/reverse or hunk matching | Not implemented by MoonChange |
| Safe change model and explicit manifest | MoonChange |
| Path-scoped owners and obligations | MoonChange |
| Approval/check/label reconciliation | MoonChange |
| Budgets, forbidden operations, release-note gate | MoonChange |
| Review plan, lint, explain, policy comparison | MoonChange |

The upstream adapter is intentionally small and replaceable. The core evaluator
operates on typed `ChangeSet` values and has no dependency on patch text.

MoonChange is also distinct from the registered hackathon projects MoonBench,
MoonContract, MoonRecur, MoonShard, MoonDag, MoonSPDX, MoonRedact, and
MoonLedger: it does not benchmark runtimes, validate OpenAPI, expand calendar
recurrences, chunk content, analyze dependency DAGs, audit SPDX licenses,
redact sensitive text, or implement accounting ledgers.
