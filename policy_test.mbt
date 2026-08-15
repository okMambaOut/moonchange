///|
test "construct policy and normalize repeated obligations" {
  let pattern = PathGlob::compile("src/**").unwrap()
  let owner = OwnerRule::new(pattern, ["@team", "@team"]).unwrap()
  assert_eq(owner.owners(), ["@team"])
  let rule = GovernanceRule::new(
    "source",
    pattern,
    approvals=2,
    checks=["unit", "lint", "unit"],
    labels=["code", "code"],
    forbidden=[Delete, Delete],
    max_lines=Some(100),
    release_note=true,
    allow_binary=false,
  ).unwrap()
  assert_eq(rule.checks(), ["lint", "unit"])
  assert_eq(rule.labels(), ["code"])
  assert_eq(rule.forbidden(), [Delete])
  assert_false(rule.allows_binary())
  let policy = Policy::new(owner_rules=[owner], rules=[rule]).unwrap()
  assert_eq(policy.rules().length(), 1)
}

///|
test "policy constructors reject invalid principals duplicate names and limits" {
  let pattern = PathGlob::compile("**").unwrap()
  assert_eq(
    OwnerRule::new(pattern, []).unwrap_err().code(),
    "policy.owner.empty",
  )
  assert_eq(
    OwnerRule::new(pattern, ["team"]).unwrap_err().code(),
    "policy.principal.invalid",
  )
  assert_eq(
    GovernanceRule::new("bad name", pattern).unwrap_err().code(),
    "policy.rule.name",
  )
  assert_eq(
    GovernanceRule::new("x", pattern, approvals=21).unwrap_err().code(),
    "policy.approvals.limit",
  )
  let one = GovernanceRule::new("same", pattern).unwrap()
  let two = GovernanceRule::new("same", pattern).unwrap()
  assert_eq(
    Policy::new(rules=[one, two]).unwrap_err().code(),
    "policy.rule.duplicate",
  )
}
