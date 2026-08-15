///|
test "lint accepts a covered policy with meaningful rules" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=yes\nOWNER **/* @maintainers\nRULE source src/** checks=unit",
  ).unwrap()
  assert_true(lint_policy(policy).is_clean())
}

///|
test "lint reports owner coverage override and empty rule" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=yes\nOWNER src/** @one\nOWNER src/** @two\nRULE empty docs/**",
  ).unwrap()
  let report = lint_policy(policy)
  assert_true(report.has_code("lint.owner.overridden"))
  assert_true(report.has_code("lint.owner.no_global_coverage"))
  assert_true(report.has_code("lint.rule.empty"))
  assert_false(report.has_errors())
}

///|
test "lint rejects required ownership without owner rules" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=yes\nRULE source src/** approvals=1",
  ).unwrap()
  let report = lint_policy(policy)
  assert_true(report.has_errors())
  assert_true(report.has_code("lint.owner.none"))
  assert_true(report.has_code("lint.approval.unscoped"))
  assert_true(report.to_text().contains("CLEAN no"))
}

///|
test "explain renders aggregated obligations" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=no\nRULE source src/** checks=unit labels=code forbid=delete max_lines=20 release_note=yes binary=deny",
  ).unwrap()
  let text = policy.explain("src/main.mbt").unwrap().to_text()
  assert_true(text.contains("RULES source"))
  assert_true(text.contains("CHECKS unit"))
  assert_true(text.contains("FORBID delete"))
  assert_true(text.contains("BINARY deny"))
}
