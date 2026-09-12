# Changelog

## 0.2.1 — 2026-09-12

- Publish the maintenance distribution under `ZJH-666-ZJH/moonchange`; retain the original repository and attribution.
- Reduce character and path glob DP state to a single row without API changes.
- Add 13,091 exhaustive recursive-oracle pairs plus length/depth regressions.
- Document reproducible quality bounds and contributor attribution.

## 0.2.0 - 2026-08-25

- Preserve absent total and per-path line budgets across canonical round trips.
- Reconcile duplicate library check states conservatively so failed or pending
  evidence cannot be masked by a passed result.
- Reject owner approval quorums that exceed the eligible owner pool.
- Reject duplicate `RELEASE_NOTE` fields in explicit manifests.
- Add deterministic versioned JSON for audit, explain, lint, comparison, and
  demo CLI workflows through `--format text|json`.
- Expand regression coverage and CI parsing of machine-readable output.

## 0.1.0 - 2026-08-15

- Model safe repository changes, evidence, owner rules, and governance rules.
- Parse and canonically serialize policy, manifest, and evidence formats.
- Resolve owners and aggregate approval, check, label, operation, budget,
  binary, and release-note obligations.
- Emit deterministic passed/review/rejected reports and review plans.
- Lint and explain policies and compare policy effects over concrete paths.
- Integrate `mizchi/bit_apply@0.46.4` for unified-diff metadata only.
- Provide audit, audit-diff, explain, lint, compare, and demo CLI workflows.
- Add focused tests, examples, multi-target CI, and engineering documentation.
