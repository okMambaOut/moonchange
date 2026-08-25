# Support Matrix

| Behavior | Status | Notes |
| --- | --- | --- |
| Explicit change manifests | Supported | Add, modify, delete, rename, and copy |
| Review evidence files | Supported | Actor, approvals, checks, labels, release note |
| Unified Git diff metadata | Supported | Delegated to `mizchi/bit_apply@0.46.4` |
| `*`, `?`, segment `**` globs | Supported | Safe relative forward-slash paths only |
| Owner precedence | Supported | Most specific, then last matching rule |
| Rule aggregation | Supported | All matching rules contribute |
| Approval quorums | Supported | Counts approvals belonging to resolved owners |
| Required checks | Supported | Passed, failed, pending, or missing |
| Required labels | Supported | Exact stable names |
| Line budgets | Supported | Per-path minimum and policy total |
| Forbidden operations | Supported | Any change kind |
| Rename source/destination review | Supported | Both paths evaluated, lines counted once |
| Binary policy in manifests | Supported | Explicit `text` or `binary` token |
| Binary detection from diff | Unsupported | `PatchInfo` has no binary flag |
| Policy lint | Supported | Overrides, coverage, empty rules, unscoped quorum |
| Policy comparison | Supported | Concrete path inventory, deterministic delta |
| Versioned JSON reports | Supported | Audit, explain, lint, and policy comparison |
| Duplicate library check states | Supported | Strictest state wins; text inputs reject duplicates |
| Impossible owner quorum | Supported | Rejected as a blocking policy failure |
| Git commands / repository mutation | Unsupported | Input files only |
| Diff generation or hunk reconstruction | Unsupported | Outside project identity |
| Patch application or reversal | Unsupported | Use upstream tooling |
| Branch protection API integration | Unsupported | No network or GitHub dependency |
| CODEOWNERS syntax import | Unsupported | MoonChange policy is explicit and bounded |

## Diagnostics and Exit Codes

Diagnostics use stable dot-separated codes. Human-readable messages may improve
in minor versions. CLI exit codes are `0` for passed/clean, `1` for review or
lint attention, and `2` for rejection, lint errors, or invalid input.

Report commands accept `--format text|json`; omitted format means `text`.
Machine consumers should validate the JSON `schema` field before processing.

## Input Safety

Paths cannot be absolute, slash-terminated, use backslashes, or contain empty,
`.` or `..` segments. Globs reject bracket/brace syntax and embedded `**`.
Numeric fields have explicit upper bounds. Parsers accept LF and CRLF input and
emit LF canonical text. A hyphen represents an absent optional line budget and
survives parse/serialize round trips without becoming a numeric sentinel.
