///|
let evidence_fixture = "MOONCHANGE_EVIDENCE 1\nID PR-42\nACTOR @alice\nAPPROVAL @security\nAPPROVAL @maintainers\nCHECK unit passed\nLABEL code\nRELEASE_NOTE yes"

///|
test "parse and canonically serialize review evidence" {
  let document = parse_review_evidence(evidence_fixture).unwrap()
  assert_eq(document.id(), "PR-42")
  assert_eq(document.evidence().actor(), "@alice")
  assert_eq(document.evidence().approvals(), ["@maintainers", "@security"])
  assert_true(document.evidence().has_release_note())
  assert_eq(parse_review_evidence(document.to_text()).unwrap(), document)
}

///|
test "evidence parser rejects invalid structure" {
  assert_eq(
    parse_review_evidence("MOONCHANGE_EVIDENCE 2").unwrap_err().code(),
    "evidence.header",
  )
  assert_eq(
    parse_review_evidence("MOONCHANGE_EVIDENCE 1\nACTOR @a").unwrap_err().code(),
    "evidence.id.missing",
  )
  assert_eq(
    parse_review_evidence("MOONCHANGE_EVIDENCE 1\nID X").unwrap_err().code(),
    "evidence.actor.missing",
  )
  assert_eq(
    parse_review_evidence(
      "MOONCHANGE_EVIDENCE 1\nID X\nACTOR @a\nCHECK unit maybe",
    )
    .unwrap_err()
    .code(),
    "evidence.check.state",
  )
}
