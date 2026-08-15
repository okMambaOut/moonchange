///|
test "compare policies reports path-scoped obligation changes" {
  let before = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=yes\nOWNER **/* @maintainers\nRULE source src/** checks=unit max_lines=200",
  ).unwrap()
  let after = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=yes\nOWNER **/* @maintainers\nOWNER src/security/** @security\nRULE source src/** checks=unit max_lines=200\nRULE security src/security/** approvals=2 checks=security labels=reviewed forbid=delete max_lines=80 release_note=yes binary=deny",
  ).unwrap()
  let comparison = compare_policies(before, after, [
    "src/main.mbt", "src/security/auth.mbt",
  ]).unwrap()
  assert_eq(comparison.changed_count(), 1)
  assert_false(comparison.paths()[0].changed())
  let security = comparison.paths()[1]
  assert_true(security.changed())
  assert_eq(security.owners().added(), ["@security"])
  assert_eq(security.owners().removed(), ["@maintainers"])
  assert_eq(security.checks().added(), ["security"])
  assert_eq(security.labels().added(), ["reviewed"])
  assert_eq(security.forbidden().added(), ["delete"])
  assert_true(comparison.to_text().contains("approvals=1=>2"))
}

///|
test "compare policies validates path inventory" {
  let policy = Policy::new(require_owned=false).unwrap()
  assert_eq(
    compare_policies(policy, policy, []).unwrap_err().code(),
    "compare.paths.limit",
  )
  assert_eq(
    compare_policies(policy, policy, ["src/a", "src/a"]).unwrap_err().code(),
    "compare.path.duplicate",
  )
  assert_eq(
    compare_policies(policy, policy, ["../unsafe"]).unwrap_err().code(),
    "compare.path.unsafe",
  )
}
