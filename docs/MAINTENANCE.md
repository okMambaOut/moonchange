# Path matcher maintenance — 2026-09-12

Contributor: ZJH-666-ZJH (朱鋆豪). Baseline: `156ba59`.

## Scope and design

The existing matcher allocated a full Boolean matrix both within a segment and
between path segments. Replace each matrix with one mutable row. Before
replacing a cell, save its old value for the next diagonal. A star consumes
from the new left-hand cell or matches empty from the old current cell.
Whole-segment `**` follows the same rule; ordinary segments use the character
matcher. Path validation, specificity and public API are unchanged.

## Reproducible quality evidence

`glob_wbtest.mbt` adds four test groups:

- 10,571 segment pairs: every pattern of length 0–4 over `a,b,*,?`, crossed
  with every value of length 0–4 over `a,b`. Independent recursive enumeration
  tries each possible wildcard span instead of building DP rows.
- 2,520 path pairs: patterns of 1–3 segments over `a,b,*,**`, crossed with
  values of 1–4 segments over `a,b`.
- Legal 1,024-character literal/wildcard inputs, 512-segment paths, and rejection
  beyond the length limit.
- Empty wildcard consumption, repeated `**`, Chinese BMP characters, and unsafe
  paths. This is not a claim of complete Unicode/grapheme conformance.

The new suite also passes against the baseline implementation, before restoring
the optimized implementation. The complete suite grows from 38 to 42 groups;
13,091 generated oracle pairs are assertions within two groups, not 13,091
separate test groups. Local wasm-gc, wasm and js strict checks/tests pass.
Native strict checking passes, but local execution is unavailable without a C
compiler. GitHub Actions additionally runs native tests and CLI smoke tests.
See `verification/` for the local logs; remote CI is a separate result.

## Quantitative bounds, not an RSS benchmark

For a pattern of P character units and value of V units, Boolean state slots
fall from `(P+1)*(V+1)` to `V+1`. At P=V=1024: **1,050,625 → 1,025 slots**,
a **99.9024%** reduction. For two 512-segment paths: **263,169 → 513 slots**,
a **99.8051%** reduction in the outer matcher table. Inner matching state is
additional. Neither figure measures process RSS, allocation bytes, throughput,
or end-to-end CI speed. Time remains O(P×V); no speedup is claimed.

Reproduce with `moon test --target wasm-gc --deny-warn` (or wasm/js/native),
`moon fmt --check` and `moon check --target wasm-gc --deny-warn`.
Public interface generation with `moon info` produces no interface diff.

## Position relative to CODEOWNERS

GitHub CODEOWNERS is the adjacent ownership-routing baseline, not a
performance benchmark. MoonChange combines path ownership with checks, labels,
line budgets, operation restrictions and release-note obligations in an offline
review plan. Its owner selection uses highest specificity, then last-rule tie
breaking: **do not treat it as a drop-in CODEOWNERS interpreter**. It neither
fetches GitHub evidence nor enforces branch protection. Input evidence must come
from a trusted integration. Binary rules require an explicit manifest because
the upstream diff metadata does not expose binary classification.

Reference for users comparing workflows:
https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
