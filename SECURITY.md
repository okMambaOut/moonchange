# Security Policy

## Supported Version

Security fixes apply to the latest release line.

## Reporting

After the public repository is available, report vulnerabilities privately with
GitHub Security Advisories. Do not place secrets, confidential diffs, or private
repository policy files in public issues.

## Threat Model

MoonChange treats policy, manifest, evidence, diff text, paths, numeric values,
and CLI file names as untrusted input. It bounds input sizes and counts, rejects
unsafe repository paths, uses deterministic parsers, and performs no repository
mutation, Git invocation, networking, dynamic loading, or code execution.

The CLI reads user-selected UTF-8 files. Consumers remain responsible for OS
file permissions, symlink handling, secret classification, authorization of
approver identities, and mapping reported checks to trusted CI providers.

Diff parsing is delegated to `mizchi/bit_apply@0.46.4`; monitor that dependency
for upstream fixes. Explicit manifests are required when binary classification
must be enforced.
