# Contributing

Use a current MoonBit toolchain and keep changes within repository governance.
Before opening a change, run:

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
```

Add positive, negative, boundary, and canonical round-trip tests for behavior
changes. New syntax must define limits, diagnostics, and aggregation semantics.
Preserve deterministic output ordering and repository-relative path safety.

Do not add custom diff generation, hunk parsing/matching, patch application, or
patch reversal. Improvements to diff input should use a mature ecosystem
package and retain attribution in `THIRD_PARTY.md`.
