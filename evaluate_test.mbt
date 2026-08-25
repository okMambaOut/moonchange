///|
fn evaluation_policy() -> Policy {
  parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 max_total=300 require_owned=yes\nOWNER **/* @maintainers\nOWNER src/security/** @security,@maintainers\nRULE source src/** approvals=1 checks=unit labels=code forbid=delete max_lines=200 release_note=no binary=deny\nRULE security src/security/** approvals=2 checks=security labels=security-reviewed forbid=rename max_lines=80 release_note=yes binary=deny",
  ).unwrap()
}

///|
test "evaluate complete evidence as passed" {
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-1\nACTOR @alice\nAPPROVAL @maintainers\nAPPROVAL @security\nCHECK unit passed\nCHECK security passed\nLABEL code\nLABEL security-reviewed\nRELEASE_NOTE yes\nCHANGE modify src/security/auth.mbt 30 10 text",
  ).unwrap()
  let report = evaluate(evaluation_policy(), manifest)
  assert_eq(report.status(), GateStatus::Passed)
  assert_eq(report.total_lines(), 40)
  assert_eq(report.findings(), [])
  let decision = report.decisions()[0]
  assert_eq(decision.owners(), ["@security", "@maintainers"])
  assert_eq(decision.approvals(), 2)
  assert_eq(decision.checks(), ["security", "unit"])
  assert_eq(decision.labels(), ["code", "security-reviewed"])
  assert_eq(decision.matched_rules(), ["security", "source"])
  assert_eq(decision.owner_pattern(), Some("src/security/**"))
  let plan = report.plan()
  assert_eq(plan.required_owners(), ["@maintainers", "@security"])
  assert_eq(plan.approved_owners(), ["@maintainers", "@security"])
  assert_eq(plan.unapproved_owners(), [])
  assert_eq(plan.required_checks(), ["security", "unit"])
  assert_eq(plan.passed_checks(), ["security", "unit"])
  assert_eq(plan.missing_labels(), [])
  assert_eq(plan.touched_rules(), ["security", "source"])
  assert_eq(plan.maximum_path_approvals(), 2)
  assert_true(plan.requires_release_note())
  assert_true(plan.has_release_note())
}

///|
test "missing review evidence produces review status" {
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-2\nACTOR @alice\nAPPROVAL @maintainers\nCHECK unit passed\nCHECK security pending\nLABEL code\nRELEASE_NOTE no\nCHANGE modify src/security/auth.mbt 10 2 text",
  ).unwrap()
  let report = evaluate(evaluation_policy(), manifest)
  assert_eq(report.status(), Review)
  assert_true(report.has_code("approval.missing"))
  assert_true(report.has_code("check.pending"))
  assert_true(report.has_code("label.missing"))
  assert_true(report.has_code("release_note.missing"))
  assert_false(report.has_code("check.missing"))
  assert_eq(report.plan().unapproved_owners(), ["@security"])
  assert_eq(report.plan().unresolved_checks(), ["security"])
  assert_eq(report.plan().missing_labels(), ["security-reviewed"])
}

///|
test "hard policy failures reject change" {
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-3\nACTOR @alice\nAPPROVAL @maintainers\nAPPROVAL @security\nCHECK unit failed\nCHECK security passed\nLABEL code\nLABEL security-reviewed\nRELEASE_NOTE yes\nCHANGE rename src/security/old.bin src/security/new.bin 60 40 binary\nCHANGE delete src/legacy.mbt 0 250 text",
  ).unwrap()
  let report = evaluate(evaluation_policy(), manifest)
  assert_eq(report.status(), Rejected)
  assert_true(report.has_code("operation.forbidden"))
  assert_true(report.has_code("budget.path.exceeded"))
  assert_true(report.has_code("binary.forbidden"))
  assert_true(report.has_code("check.failed"))
  assert_true(report.has_code("budget.total.exceeded"))
}

///|
test "failed duplicate check dominates passed library evidence" {
  let evidence = Evidence::new(
    "@alice",
    ["@maintainers"],
    [
      CheckResult::new("unit", CheckState::Passed),
      CheckResult::new("unit", Failed),
    ],
    ["code"],
  )
  let changes = ChangeSet::new(
    "API-1",
    [
      Change::new(Modify, Some("src/main.mbt"), Some("src/main.mbt"), 1, 0).unwrap(),
    ],
    evidence,
  ).unwrap()
  let report = evaluate(evaluation_policy(), changes)
  assert_eq(report.status(), Rejected)
  assert_true(report.has_code("check.failed"))
  assert_eq(report.plan().passed_checks(), [])
  assert_eq(report.plan().unresolved_checks(), ["unit"])
}

///|
test "impossible owner quorum is a blocking policy failure" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=2 require_owned=yes\nOWNER **/* @maintainers",
  ).unwrap()
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-IMPOSSIBLE\nACTOR @alice\nAPPROVAL @maintainers\nRELEASE_NOTE no\nCHANGE modify src/main.mbt 1 0 text",
  ).unwrap()
  let report = evaluate(policy, manifest)
  assert_eq(report.status(), Rejected)
  assert_true(report.has_code("approval.quorum.impossible"))
  assert_false(report.has_code("approval.missing"))
}

///|
test "unowned paths reject when ownership is required" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=yes\nOWNER src/** @source",
  ).unwrap()
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-4\nACTOR @alice\nRELEASE_NOTE no\nCHANGE add docs/readme.md 1 0 text",
  ).unwrap()
  let report = evaluate(policy, manifest)
  assert_eq(report.status(), Rejected)
  assert_true(report.has_code("owner.unassigned"))
}

///|
test "owner selection prefers specificity and then last match" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=yes\nOWNER **/* @all\nOWNER src/** @source\nOWNER src/?ore/** @core\nOWNER src/core/** @core-last",
  ).unwrap()
  let decision = policy.explain("src/core/api.mbt").unwrap()
  assert_eq(decision.owners(), ["@core-last"])
  assert_eq(decision.owner_pattern(), Some("src/core/**"))
  assert_eq(
    policy.explain("bad/../path").unwrap_err().code(),
    "explain.path.unsafe",
  )
}

///|
test "rename is governed at both source and destination paths" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=no\nRULE source src/security/** forbid=rename\nRULE destination docs/** labels=documentation",
  ).unwrap()
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-MOVE\nACTOR @alice\nRELEASE_NOTE no\nCHANGE rename src/security/guide.md docs/guide.md 0 0 text",
  ).unwrap()
  let report = evaluate(policy, manifest)
  assert_eq(report.decisions().length(), 2)
  assert_eq(report.decisions()[0].path(), "src/security/guide.md")
  assert_eq(report.decisions()[1].path(), "docs/guide.md")
  assert_true(report.has_code("operation.forbidden"))
  assert_true(report.has_code("label.missing"))
  assert_eq(report.total_lines(), 0)
}

///|
test "report text is deterministic and contains evidence" {
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID PR-5\nACTOR @alice\nAPPROVAL @maintainers\nCHECK unit passed\nLABEL code\nRELEASE_NOTE no\nCHANGE modify src/main.mbt 2 1 text",
  ).unwrap()
  let report = evaluate(evaluation_policy(), manifest)
  let text = report.to_text()
  assert_true(text.contains("STATUS passed"))
  assert_true(text.contains("PATH src/main.mbt owners=@maintainers"))
  assert_eq(
    evaluate(evaluation_policy(), parse_manifest(manifest.to_text()).unwrap()).to_text(),
    text,
  )
}
