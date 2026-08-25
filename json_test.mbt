///|
test "json string escaping is valid and deterministic" {
  let finding = Finding::new(
    Attention,
    "json.escape",
    "src/中.mbt",
    "quote\" slash\\ line\n tab\t zero\u{0}",
  )
  assert_eq(
    finding.to_json(),
    "{\"level\":\"attention\",\"code\":\"json.escape\",\"path\":\"src/中.mbt\",\"message\":\"quote\\\" slash\\\\ line\\n tab\\t zero\\u0000\"}",
  )
}

///|
test "audit lint explain and compare expose versioned json" {
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=yes\nOWNER **/* @maintainers\nRULE source src/** checks=unit",
  ).unwrap()
  let manifest = parse_manifest(
    "MOONCHANGE 1\nID JSON-1\nACTOR @alice\nAPPROVAL @maintainers\nCHECK unit passed\nRELEASE_NOTE no\nCHANGE modify src/main.mbt 1 0 text",
  ).unwrap()
  let report = evaluate(policy, manifest)
  let audit_json = report.to_json()
  assert_true(audit_json.contains("\"schema\":\"moonchange.audit.v1\""))
  assert_true(audit_json.contains("\"status\":\"passed\""))
  assert_true(audit_json.contains("\"required_checks\":[\"unit\"]"))
  let explain_json = policy.explain("src/main.mbt").unwrap().to_explain_json()
  assert_true(explain_json.contains("\"schema\":\"moonchange.explain.v1\""))
  assert_true(explain_json.contains("\"path\":\"src/main.mbt\""))
  assert_true(lint_policy(policy).to_json().contains("\"clean\":true"))
  let comparison = compare_policies(policy, policy, ["src/main.mbt"]).unwrap()
  assert_true(comparison.to_json().contains("\"changed_count\":0"))
}
