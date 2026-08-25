///|
pub struct ReviewEvidence {
  id : String
  evidence : Evidence
} derive(Eq, @debug.Debug)

///|
pub fn ReviewEvidence::id(self : ReviewEvidence) -> String {
  self.id
}

///|
pub fn ReviewEvidence::evidence(self : ReviewEvidence) -> Evidence {
  self.evidence
}

///|
pub fn parse_review_evidence(
  source : String,
) -> Result[ReviewEvidence, Diagnostic] {
  if source.is_empty() || source.length() > 1048576 {
    return Err(
      Diagnostic::new(
        "evidence.input.limit",
        "evidence",
        "evidence is empty or exceeds the input limit",
        "1 through 1048576 characters",
        source.length().to_string(),
      ),
    )
  }
  let lines = split_owned_lines(source)
  if lines.is_empty() || lines[0] != "MOONCHANGE_EVIDENCE 1" {
    return Err(
      syntax_error(
        "evidence.header",
        0,
        "evidence header is missing or unsupported",
        "MOONCHANGE_EVIDENCE 1",
        if lines.is_empty() {
          "end of input"
        } else {
          lines[0]
        },
      ),
    )
  }
  let mut id : String? = None
  let mut actor : String? = None
  let approvals : Array[String] = []
  let checks : Array[CheckResult] = []
  let labels : Array[String] = []
  let mut release_note = false
  let mut saw_release_note = false
  for index = 1; index < lines.length(); index = index + 1 {
    let line = lines[index]
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let fields = split_fields(line)
    match fields[0] {
      "ID" => {
        if fields.length() != 2 || id is Some(_) || !is_identifier(fields[1]) {
          return Err(
            syntax_error(
              "evidence.id.shape", index, "ID is duplicate, malformed, or invalid",
              "one simple ID value", line,
            ),
          )
        }
        id = Some(fields[1])
      }
      "ACTOR" => {
        if fields.length() != 2 || actor is Some(_) || !is_principal(fields[1]) {
          return Err(
            syntax_error(
              "evidence.actor.shape", index, "ACTOR is duplicate, malformed, or invalid",
              "one @principal", line,
            ),
          )
        }
        actor = Some(fields[1])
      }
      "APPROVAL" => {
        if fields.length() != 2 || !is_principal(fields[1]) {
          return Err(
            syntax_error(
              "evidence.approval.shape", index, "APPROVAL is malformed", "APPROVAL @principal",
              line,
            ),
          )
        }
        push_unique_string(approvals, fields[1])
      }
      "CHECK" => {
        if fields.length() != 3 || !is_simple_name(fields[1]) {
          return Err(
            syntax_error(
              "evidence.check.shape", index, "CHECK is malformed", "CHECK name passed|failed|pending",
              line,
            ),
          )
        }
        let state = match CheckState::parse(fields[2]) {
          Some(value) => value
          None =>
            return Err(
              syntax_error(
                "evidence.check.state",
                index,
                "check state is invalid",
                "passed, failed, or pending",
                fields[2],
              ),
            )
        }
        for existing in checks {
          if existing.name == fields[1] {
            return Err(
              syntax_error(
                "evidence.check.duplicate",
                index,
                "check appears more than once",
                "unique check name",
                fields[1],
              ),
            )
          }
        }
        checks.push(CheckResult::new(fields[1], state))
      }
      "LABEL" => {
        if fields.length() != 2 || !is_simple_name(fields[1]) {
          return Err(
            syntax_error(
              "evidence.label.shape", index, "LABEL is malformed", "LABEL name",
              line,
            ),
          )
        }
        push_unique_string(labels, fields[1])
      }
      "RELEASE_NOTE" => {
        if fields.length() != 2 || saw_release_note {
          return Err(
            syntax_error(
              "evidence.release_note.shape", index, "RELEASE_NOTE is duplicate or malformed",
              "one RELEASE_NOTE yes|no", line,
            ),
          )
        }
        saw_release_note = true
        release_note = match
          parse_yes_no(
            fields[1],
            "lines[" + index.to_string() + "].release_note",
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      }
      command =>
        return Err(
          syntax_error(
            "evidence.command.unknown", index, "evidence command is unknown", "ID, ACTOR, APPROVAL, CHECK, LABEL, or RELEASE_NOTE",
            command,
          ),
        )
    }
  }
  if id is None {
    return Err(
      Diagnostic::new(
        "evidence.id.missing", "evidence", "evidence has no ID", "ID value", "missing",
      ),
    )
  }
  if actor is None {
    return Err(
      Diagnostic::new(
        "evidence.actor.missing", "evidence", "evidence has no actor", "ACTOR @principal",
        "missing",
      ),
    )
  }
  approvals.sort_by(fn(left, right) { left.lexical_compare(right) })
  labels.sort_by(fn(left, right) { left.lexical_compare(right) })
  Ok({
    id: id.unwrap(),
    evidence: Evidence::new(
      actor.unwrap(),
      approvals,
      checks,
      labels,
      release_note~,
    ),
  })
}

///|
pub fn ReviewEvidence::to_text(self : ReviewEvidence) -> String {
  let output = StringBuilder()
  let release_note = if self.evidence.release_note { "yes" } else { "no" }
  output.write_string(
    "MOONCHANGE_EVIDENCE 1\nID " + self.id + "\nACTOR " + self.evidence.actor,
  )
  for approval in self.evidence.approvals {
    output.write_string("\nAPPROVAL " + approval)
  }
  for check in self.evidence.checks {
    output.write_string("\nCHECK " + check.name + " " + check.state.to_text())
  }
  for label in self.evidence.labels {
    output.write_string("\nLABEL " + label)
  }
  output.write_string("\nRELEASE_NOTE " + release_note)
  output.to_string()
}
