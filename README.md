# MoonChange

MoonChange is an original MoonBit library and CLI for repository change
governance. It turns a path-scoped policy plus change evidence into a
deterministic review plan and a `passed`, `review`, or `rejected` gate.

It is designed for maintainers who need policy-as-code for ownership routing,
approval quorums, required checks and labels, line budgets, forbidden
operations, binary restrictions, and release-note obligations.

## Why

Repository review rules are often scattered across CODEOWNERS files, CI YAML,
team conventions, and release checklists. MoonChange makes those obligations
explicit and testable before a change is merged. The same policy can audit an
explicit change manifest or metadata extracted from a Git unified diff.

MoonChange does not implement a diff algorithm or patch engine. For the optional
diff input, it calls the mature `mizchi/bit_apply@0.46.4` `parse_patches` API and
converts only its `PatchInfo` metadata into governance inputs.

## Capabilities

- Parse and canonically serialize bounded policy, manifest, and evidence files.
- Match safe repository-relative paths with `*`, `?`, and whole-segment `**`.
- Resolve owners by highest specificity, with the last rule winning ties.
- Aggregate all matching governance rules rather than selecting only one.
- Enforce owner approvals, checks, labels, per-path and total line budgets,
  forbidden operations, binary restrictions, and release-note requirements.
- Review both source and destination paths for rename operations.
- Produce stable findings, an aggregate review plan, and CI-oriented exit codes.
- Emit deterministic versioned JSON for audit, explain, lint, and comparison
  workflows without changing the default human-readable output.
- Explain one path, lint ineffective policies, and compare old/new policies for
  a concrete path inventory.
- Consume unified-diff file metadata through `mizchi/bit_apply` without
  reimplementing diff generation, hunk parsing, patch application, or reversal.

## Quick Start

Install a current [MoonBit toolchain](https://www.moonbitlang.com/download/),
then run:

```sh
moon update
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
moon run cmd/moonchange --target js -- demo
```

Audit the committed explicit manifest example:

```sh
moon run cmd/moonchange --target js -- audit \
  --policy examples/policy.mcp \
  --manifest examples/manifest.mcm \
  --format json
```

Audit the same workflow from a real Git diff plus review evidence:

```sh
moon run cmd/moonchange --target js -- audit-diff \
  --policy examples/policy.mcp \
  --evidence examples/evidence.mce \
  --diff examples/change.diff
```

Explain and lint policy behavior:

```sh
moon run cmd/moonchange --target js -- explain \
  --policy examples/policy.mcp --path src/security/auth.mbt
moon run cmd/moonchange --target js -- lint --policy examples/policy.mcp
```

Compare policy versions over a reviewed path inventory:

```sh
moon run cmd/moonchange --target js -- compare \
  --before examples/policy-before.mcp \
  --after examples/policy.mcp \
  --paths examples/paths.txt
```

Exit code `0` means passed/clean, `1` means review evidence or lint attention is
needed, and `2` means rejected or invalid input.

All report commands accept `--format text|json`. JSON documents use explicit
schema identifiers such as `moonchange.audit.v1`; field order is deterministic,
but consumers should select fields by name.

## Policy Format

```text
MOONCHANGE_POLICY 1
DEFAULT approvals=1 max_total=500 require_owned=yes
OWNER **/* @maintainers
OWNER src/security/** @security,@maintainers
RULE source src/** approvals=1 checks=unit labels=code forbid=delete max_lines=200 release_note=no binary=deny
```

Owner lists are alternatives used to satisfy the path quorum. All matching
`RULE` lines contribute obligations. Approval counts take the maximum, line
budgets take the minimum, sets are unioned, and boolean restrictions use the
strictest result. Use `max_total=-` or `max_lines=-` for no limit. A quorum
larger than the resolved owner pool is rejected as an impossible policy.

## Explicit Manifest Format

```text
MOONCHANGE 1
ID PR-42
ACTOR @alice
APPROVAL @maintainers
CHECK unit passed
LABEL code
RELEASE_NOTE no
CHANGE modify src/main.mbt 8 2 text
```

For `rename` and `copy`, provide old and new paths. Other operations take one
path. Each change ends with additions, deletions, and `text` or `binary`.

## Diff Evidence Format

`audit-diff` uses a separate `MOONCHANGE_EVIDENCE 1` file containing the same
ID, actor, approval, check, label, and release-note fields. File operations and
line counts come exclusively from upstream `PatchInfo` values.

For callers constructing `Evidence` directly, duplicate check names are
reconciled conservatively: `failed` dominates `pending`, which dominates
`passed`. Text parsers reject duplicates so file inputs remain unambiguous.

## Library

```moonbit
let policy = @moonchange.parse_policy(policy_text).unwrap()
let changes = @moonchange.parse_manifest(manifest_text).unwrap()
let report = @moonchange.evaluate(policy, changes)
inspect(report.status(), content="Passed")
```

`pkg.generated.mbti` records the complete generated public interface.

## Verification

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
```

Native compilation and execution require a C compiler. GitHub Actions performs
native checks, tests, a release build, and real CLI flows on Ubuntu.

## Boundaries

MoonChange never applies patches, reconstructs hunks, generates diffs, mutates a
repository, calls Git, contacts GitHub, or evaluates branch protection rules.
The diff adapter cannot identify binary content because upstream `PatchInfo`
does not expose that flag; use an explicit manifest when binary policy matters.
See [Support](docs/SUPPORT.md), [Architecture](docs/ARCHITECTURE.md), and
[Originality](docs/ORIGINALITY.md) for exact behavior and provenance.

## License

MoonChange is MIT licensed. Original implementation: `okMambaOut`; maintenance
contributors are recorded in [CONTRIBUTORS.md](CONTRIBUTORS.md). See [Third-Party Notices](THIRD_PARTY.md) and
[AI Usage](AI_USAGE.md).

## Maintenance quality evidence

The path matcher uses linear auxiliary state without changing its public API.
The suite includes 13,091 exhaustive oracle pairs and maximum-length/depth
regressions. See [the maintenance report](docs/MAINTENANCE.md) for exact scope,
state-slot reductions, reproduction commands and measurement limitations.

## MoonCakes distribution

The maintained release is distributed as `ZJH-666-ZJH/moonchange@0.2.1`:

```sh
moon add ZJH-666-ZJH/moonchange@0.2.1
```

Import `ZJH-666-ZJH/moonchange` in your package manifest (for example with
alias `moonchange`). The repository remains `okMambaOut/moonchange`; this is
an explicitly attributed maintenance distribution, not a claim that the
original project was authored by ZJH-666-ZJH. Existing consumers of an older
namespace must update their module dependency and package import paths.
