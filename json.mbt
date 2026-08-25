///|
fn json_string(value : String) -> String {
  let output = StringBuilder::new()
  output.write_char('"')
  for char in value {
    match char {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      other =>
        if other.to_int() < 32 {
          let hex = other.to_int().to_string(radix=16)
          let padded = if hex.length() == 1 { "0" + hex } else { hex }
          output.write_string("\\u00" + padded)
        } else {
          output.write_char(other)
        }
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
fn json_strings(values : Array[String]) -> String {
  let output = StringBuilder::new()
  output.write_char('[')
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(json_string(value))
  }
  output.write_char(']')
  output.to_string()
}

///|
fn json_optional_string(value : String?) -> String {
  match value {
    Some(actual) => json_string(actual)
    None => "null"
  }
}

///|
fn json_optional_int(value : Int?) -> String {
  match value {
    Some(actual) => actual.to_string()
    None => "null"
  }
}

///|
fn json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn json_kinds(values : Array[ChangeKind]) -> String {
  json_strings(values.map(fn(kind) { kind.to_text() }))
}

///|
pub fn Finding::to_json(self : Finding) -> String {
  "{" +
  "\"level\":" +
  json_string(self.level.to_text()) +
  ",\"code\":" +
  json_string(self.code) +
  ",\"path\":" +
  json_string(self.path) +
  ",\"message\":" +
  json_string(self.message) +
  "}"
}

///|
pub fn PathDecision::to_json(self : PathDecision) -> String {
  "{" +
  "\"path\":" +
  json_string(self.path) +
  ",\"owners\":" +
  json_strings(self.owners) +
  ",\"owner_pattern\":" +
  json_optional_string(self.owner_pattern) +
  ",\"matched_rules\":" +
  json_strings(self.matched_rules) +
  ",\"approvals\":" +
  self.approvals.to_string() +
  ",\"checks\":" +
  json_strings(self.checks) +
  ",\"labels\":" +
  json_strings(self.labels) +
  ",\"forbidden\":" +
  json_kinds(self.forbidden) +
  ",\"max_lines\":" +
  json_optional_int(self.max_lines) +
  ",\"release_note\":" +
  json_bool(self.release_note) +
  ",\"allow_binary\":" +
  json_bool(self.allow_binary) +
  "}"
}

///|
pub fn PathDecision::to_explain_json(self : PathDecision) -> String {
  "{\"schema\":\"moonchange.explain.v1\",\"decision\":" + self.to_json() + "}"
}

///|
pub fn ReviewPlan::to_json(self : ReviewPlan) -> String {
  "{" +
  "\"required_owners\":" +
  json_strings(self.required_owners) +
  ",\"approved_owners\":" +
  json_strings(self.approved_owners) +
  ",\"unapproved_owners\":" +
  json_strings(self.unapproved_owners) +
  ",\"required_checks\":" +
  json_strings(self.required_checks) +
  ",\"passed_checks\":" +
  json_strings(self.passed_checks) +
  ",\"unresolved_checks\":" +
  json_strings(self.unresolved_checks) +
  ",\"required_labels\":" +
  json_strings(self.required_labels) +
  ",\"present_labels\":" +
  json_strings(self.present_labels) +
  ",\"missing_labels\":" +
  json_strings(self.missing_labels) +
  ",\"touched_rules\":" +
  json_strings(self.touched_rules) +
  ",\"maximum_path_approvals\":" +
  self.maximum_path_approvals.to_string() +
  ",\"release_note_required\":" +
  json_bool(self.release_note_required) +
  ",\"release_note_present\":" +
  json_bool(self.release_note_present) +
  "}"
}

///|
pub fn AuditReport::to_json(self : AuditReport) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"schema\":\"moonchange.audit.v1\",\"change_id\":" +
    json_string(self.change_id) +
    ",\"status\":" +
    json_string(self.status.to_text()) +
    ",\"total_lines\":" +
    self.total_lines.to_string() +
    ",\"decisions\":[",
  )
  for index, decision in self.decisions {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(decision.to_json())
  }
  output.write_string("],\"findings\":[")
  for index, finding in self.findings {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(finding.to_json())
  }
  output.write_string("],\"plan\":" + self.plan.to_json() + "}")
  output.to_string()
}

///|
pub fn LintIssue::to_json(self : LintIssue) -> String {
  "{" +
  "\"level\":" +
  json_string(self.level.to_text()) +
  ",\"code\":" +
  json_string(self.code) +
  ",\"subject\":" +
  json_string(self.subject) +
  ",\"message\":" +
  json_string(self.message) +
  "}"
}

///|
pub fn LintReport::to_json(self : LintReport) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"schema\":\"moonchange.lint.v1\",\"clean\":" +
    json_bool(self.issues.is_empty()) +
    ",\"has_errors\":" +
    json_bool(self.has_errors()) +
    ",\"issues\":[",
  )
  for index, issue in self.issues {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(issue.to_json())
  }
  output.write_string("]}")
  output.to_string()
}

///|
pub fn StringDelta::to_json(self : StringDelta) -> String {
  "{\"added\":" +
  json_strings(self.added) +
  ",\"removed\":" +
  json_strings(self.removed) +
  "}"
}

///|
pub fn PathPolicyDelta::to_json(self : PathPolicyDelta) -> String {
  "{" +
  "\"path\":" +
  json_string(self.path) +
  ",\"changed\":" +
  json_bool(self.changed()) +
  ",\"before\":" +
  self.before.to_json() +
  ",\"after\":" +
  self.after.to_json() +
  ",\"owners\":" +
  self.owners.to_json() +
  ",\"rules\":" +
  self.rules.to_json() +
  ",\"checks\":" +
  self.checks.to_json() +
  ",\"labels\":" +
  self.labels.to_json() +
  ",\"forbidden\":" +
  self.forbidden.to_json() +
  "}"
}

///|
pub fn PolicyComparison::to_json(self : PolicyComparison) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"schema\":\"moonchange.compare.v1\",\"path_count\":" +
    self.paths.length().to_string() +
    ",\"changed_count\":" +
    self.changed_count().to_string() +
    ",\"paths\":[",
  )
  for index, path in self.paths {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(path.to_json())
  }
  output.write_string("]}")
  output.to_string()
}
