# Architecture

MoonChange separates input acquisition from deterministic governance logic.

```text
policy text -> policy parser -> Policy --------------------------+
                                                               |
manifest text -> manifest parser -> ChangeSet ------------------+-> evaluator
                                                               |      |
Git diff -> mizchi/bit_apply::parse_patches -> adapter ---------+      +-> AuditReport
review evidence -> evidence parser -----------------------------+          + review plan

Policy -> explain / lint
Policy A + Policy B + paths -> comparison report
```

## Domain Model

`Change` captures only repository operation metadata: kind, safe old/new paths,
line counts, and explicit binary state. `Evidence` contains the actor,
approving principals, named check states, labels, and release-note presence.
`Policy` owns ordered owner rules and aggregating governance rules.

The model copies caller arrays at public boundaries. Parsers enforce bounded
input, stable diagnostic codes, normalized repository-relative paths, unique
names where ambiguity would matter, and canonical serialization.

## Matching and Aggregation

`PathGlob` splits both patterns and paths into slash-delimited segments. A
bounded rolling dynamic-programming row evaluates `*` and `?` within a segment;
another rolling row evaluates whole-segment `**`. Matching is deterministic and does
not touch the filesystem.

Among matching owner rules, greatest specificity wins; a later rule wins an
equal-specificity tie. Every matching governance rule contributes. Checks,
labels, forbidden operations, and rule names form unique sorted unions.
Approval quorum uses the maximum and line budget uses the minimum. Release-note
requirements and binary denials are monotonic, so a weaker rule cannot cancel a
stricter one.

Rename operations are evaluated at both old and new paths. This prevents a move
from escaping source-area governance. Total changed lines are counted once.

## Gate Semantics

Hard policy violations produce `rejected`: unowned paths when ownership is
mandatory, forbidden operations, path/total budget overflow, denied binary
content, and failed checks. Missing approvals, missing/pending checks, labels,
or release notes produce `review`. With no findings the result is `passed`.

Reports retain ordered per-path decisions and findings. `ReviewPlan` aggregates
owners, checks, labels, touched rules, maximum path quorum, and release-note
state for consumers that need a concise checklist.

When library callers provide repeated states for the same check, evaluation
uses the strictest result (`failed`, then `pending`, then `passed`). Owner
quorums larger than the eligible owner set are blocking configuration failures,
not indefinitely pending reviews.

## Output Adapters

Every report model owns both a stable text renderer and a compact JSON renderer.
JSON strings escape quotes, backslashes, common whitespace, and all remaining
control characters. Versioned schema names separate audit, lint, and policy
comparison documents. The CLI selects an adapter only after evaluation, so
format choice cannot affect the gate decision or exit code.

## Upstream Diff Boundary

`diff_adapter.mbt` calls `@bit_apply.parse_patches` and reads public `PatchInfo`
fields. It performs no textual hunk parsing or patch operations. Path safety and
MoonChange model invariants are still checked after conversion. Upstream does
not expose binary classification, so adapted changes conservatively have
`binary=false`; callers needing binary enforcement must use explicit manifests.

## Complexity and Limits

- Policy/manifest parsing: linear in bounded source size.
- Segment glob: `O(segment_chars)` auxiliary state, `O(pattern_chars * segment_chars)` time.
- Path glob: `O(path_segments)` auxiliary state, `O(pattern_segments * path_segments)` time.
- Evaluation: changes multiplied by ordered owner/rule counts and evidence size.
- Policy comparison: requested paths multiplied by both policy match costs.
- Policy/manifest source: 4 MiB; evidence source: 1 MiB; diff adapter: 16 MiB.
- Change count and comparison path count: at most 10,000.
