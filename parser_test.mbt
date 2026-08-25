///|
let policy_fixture = "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 max_total=500 require_owned=yes\nOWNER **/* @maintainers\nOWNER src/security/** @security,@maintainers\nRULE source src/** approvals=2 checks=unit,lint labels=code forbid=delete max_lines=200 release_note=yes binary=deny\nRULE docs docs/** approvals=1 checks=docs labels=documentation forbid=- max_lines=100 release_note=no binary=deny"

///|
let manifest_fixture = "MOONCHANGE 1\nID PR-42\nACTOR @alice\nAPPROVAL @maintainers\nAPPROVAL @security\nCHECK unit passed\nCHECK lint passed\nLABEL code\nRELEASE_NOTE yes\nCHANGE modify src/security/auth.mbt 20 4 text\nCHANGE add docs/auth.md 30 0 text"

///|
test "parse and canonically serialize policy" {
  let policy = parse_policy(policy_fixture).unwrap()
  assert_eq(policy.default_approvals(), 1)
  assert_eq(policy.max_total_lines(), Some(500))
  assert_true(policy.requires_owned_paths())
  assert_eq(policy.owner_rules().length(), 2)
  assert_eq(policy.rules().length(), 2)
  let canonical = policy.to_text()
  assert_eq(parse_policy(canonical).unwrap(), policy)
  assert_true(canonical.contains("RULE source src/** approvals=2"))
}

///|
test "policy round trip preserves absent line budgets" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=0 require_owned=no\nRULE observe **/* checks=unit",
  ).unwrap()
  assert_eq(policy.max_total_lines(), None)
  assert_eq(policy.rules()[0].max_lines(), None)
  let canonical = policy.to_text()
  assert_true(canonical.contains("max_total=-"))
  assert_true(canonical.contains("max_lines=-"))
  assert_eq(parse_policy(canonical).unwrap(), policy)
}

///|
test "parse and canonically serialize change manifest" {
  let changes = parse_manifest(manifest_fixture).unwrap()
  assert_eq(changes.id(), "PR-42")
  assert_eq(changes.changes().length(), 2)
  assert_eq(changes.evidence().actor(), "@alice")
  assert_eq(changes.evidence().approvals(), ["@maintainers", "@security"])
  assert_true(changes.evidence().has_release_note())
  assert_eq(parse_manifest(changes.to_text()).unwrap(), changes)
}

///|
test "policy parser rejects malformed defaults owners rules and options" {
  assert_eq(
    parse_policy("MOONCHANGE_POLICY 2").unwrap_err().code(),
    "policy.header",
  )
  assert_eq(
    parse_policy(
      "MOONCHANGE_POLICY 1\nDEFAULT approvals=1\nDEFAULT approvals=2",
    )
    .unwrap_err()
    .code(),
    "policy.default.duplicate",
  )
  assert_eq(
    parse_policy("MOONCHANGE_POLICY 1\nOWNER src/** nobody").unwrap_err().code(),
    "policy.principal.invalid",
  )
  assert_eq(
    parse_policy("MOONCHANGE_POLICY 1\nRULE x src/** mystery=yes")
    .unwrap_err()
    .code(),
    "policy.option.unknown",
  )
  assert_eq(
    parse_policy("MOONCHANGE_POLICY 1\nRULE x src/** binary=maybe")
    .unwrap_err()
    .code(),
    "policy.binary.invalid",
  )
  assert_eq(
    parse_policy("MOONCHANGE_POLICY 1\nRULE x src/** forbid=explode")
    .unwrap_err()
    .code(),
    "policy.kind.invalid",
  )
}

///|
test "manifest parser rejects malformed evidence and changes" {
  assert_eq(
    parse_manifest("MOONCHANGE 2").unwrap_err().code(),
    "manifest.header",
  )
  assert_eq(
    parse_manifest("MOONCHANGE 1\nACTOR @a\nCHANGE add x 1 0 text")
    .unwrap_err()
    .code(),
    "manifest.id.missing",
  )
  assert_eq(
    parse_manifest("MOONCHANGE 1\nID X\nCHANGE add x 1 0 text")
    .unwrap_err()
    .code(),
    "manifest.actor.missing",
  )
  assert_eq(
    parse_manifest(
      "MOONCHANGE 1\nID X\nACTOR @a\nCHECK unit unknown\nCHANGE add x 1 0 text",
    )
    .unwrap_err()
    .code(),
    "manifest.check.state",
  )
  assert_eq(
    parse_manifest(
      "MOONCHANGE 1\nID X\nACTOR @a\nCHANGE rename old new 1 1 blob",
    )
    .unwrap_err()
    .code(),
    "manifest.content.invalid",
  )
  assert_eq(
    parse_manifest(
      "MOONCHANGE 1\nID X\nACTOR @a\nCHANGE modify old new 1 1 text",
    )
    .unwrap_err()
    .code(),
    "manifest.change.shape",
  )
  assert_eq(
    parse_manifest(
      "MOONCHANGE 1\nID X\nACTOR @a\nRELEASE_NOTE no\nRELEASE_NOTE yes\nCHANGE add x 1 0 text",
    )
    .unwrap_err()
    .code(),
    "manifest.release_note.shape",
  )
}
