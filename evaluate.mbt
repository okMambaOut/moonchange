///|
pub(all) enum GateStatus {
  Passed
  Review
  Rejected
} derive(Eq, @debug.Debug)

///|
pub fn GateStatus::to_text(self : GateStatus) -> String {
  match self {
    Passed => "passed"
    Review => "review"
    Rejected => "rejected"
  }
}

///|
pub(all) enum FindingLevel {
  Attention
  Blocking
} derive(Eq, @debug.Debug)

///|
pub fn FindingLevel::to_text(self : FindingLevel) -> String {
  match self {
    Attention => "attention"
    Blocking => "blocking"
  }
}

///|
pub struct Finding {
  level : FindingLevel
  code : String
  path : String
  message : String
} derive(Eq, @debug.Debug)

///|
pub fn Finding::new(
  level : FindingLevel,
  code : String,
  path : String,
  message : String,
) -> Finding {
  { level, code, path, message }
}

///|
pub fn Finding::level(self : Finding) -> FindingLevel {
  self.level
}

///|
pub fn Finding::code(self : Finding) -> String {
  self.code
}

///|
pub fn Finding::path(self : Finding) -> String {
  self.path
}

///|
pub fn Finding::message(self : Finding) -> String {
  self.message
}

///|
pub fn Finding::to_text(self : Finding) -> String {
  self.level.to_text() + " " + self.code + " " + self.path + ": " + self.message
}

///|
pub struct PathDecision {
  path : String
  owners : Array[String]
  owner_pattern : String?
  matched_rules : Array[String]
  approvals : Int
  checks : Array[String]
  labels : Array[String]
  forbidden : Array[ChangeKind]
  max_lines : Int?
  release_note : Bool
  allow_binary : Bool
} derive(Eq, @debug.Debug)

///|
pub fn PathDecision::path(self : PathDecision) -> String {
  self.path
}

///|
pub fn PathDecision::owners(self : PathDecision) -> Array[String] {
  self.owners.copy()
}

///|
pub fn PathDecision::owner_pattern(self : PathDecision) -> String? {
  self.owner_pattern
}

///|
pub fn PathDecision::matched_rules(self : PathDecision) -> Array[String] {
  self.matched_rules.copy()
}

///|
pub fn PathDecision::approvals(self : PathDecision) -> Int {
  self.approvals
}

///|
pub fn PathDecision::checks(self : PathDecision) -> Array[String] {
  self.checks.copy()
}

///|
pub fn PathDecision::labels(self : PathDecision) -> Array[String] {
  self.labels.copy()
}

///|
pub fn PathDecision::forbidden(self : PathDecision) -> Array[ChangeKind] {
  self.forbidden.copy()
}

///|
pub fn PathDecision::max_lines(self : PathDecision) -> Int? {
  self.max_lines
}

///|
pub fn PathDecision::requires_release_note(self : PathDecision) -> Bool {
  self.release_note
}

///|
pub fn PathDecision::allows_binary(self : PathDecision) -> Bool {
  self.allow_binary
}

///|
fn resolve_path(policy : Policy, path : String) -> PathDecision {
  let mut owners : Array[String] = []
  let mut owner_pattern : String? = None
  let mut owner_specificity = -1
  for rule in policy.owner_rules {
    if rule.pattern.matches(path) &&
      rule.pattern.specificity() >= owner_specificity {
      owners = rule.owners.copy()
      owner_pattern = Some(rule.pattern.source())
      owner_specificity = rule.pattern.specificity()
    }
  }
  let matched_rules : Array[String] = []
  let checks : Array[String] = []
  let labels : Array[String] = []
  let forbidden : Array[ChangeKind] = []
  let mut approvals = policy.default_approvals
  let mut max_lines : Int? = None
  let mut release_note = false
  let mut allow_binary = true
  for rule in policy.rules {
    if !rule.pattern.matches(path) {
      continue
    }
    matched_rules.push(rule.name)
    if rule.approvals > approvals {
      approvals = rule.approvals
    }
    for check in rule.checks {
      push_unique_string(checks, check)
    }
    for label in rule.labels {
      push_unique_string(labels, label)
    }
    for kind in rule.forbidden {
      if !contains_kind(forbidden, kind) {
        forbidden.push(kind)
      }
    }
    match rule.max_lines {
      Some(value) =>
        match max_lines {
          Some(current) => if value < current { max_lines = Some(value) }
          None => max_lines = Some(value)
        }
      None => ()
    }
    release_note = release_note || rule.release_note
    allow_binary = allow_binary && rule.allow_binary
  }
  checks.sort_by(fn(left, right) { left.lexical_compare(right) })
  labels.sort_by(fn(left, right) { left.lexical_compare(right) })
  matched_rules.sort_by(fn(left, right) { left.lexical_compare(right) })
  {
    path,
    owners,
    owner_pattern,
    matched_rules,
    approvals,
    checks,
    labels,
    forbidden,
    max_lines,
    release_note,
    allow_binary,
  }
}

///|
pub fn Policy::explain(
  self : Policy,
  path : String,
) -> Result[PathDecision, Diagnostic] {
  if !is_safe_repo_path(path) {
    return Err(
      Diagnostic::new(
        "explain.path.unsafe", "path", "path is not repository-relative and normalized",
        "safe repository-relative path", path,
      ),
    )
  }
  Ok(resolve_path(self, path))
}

///|
fn check_state(evidence : Evidence, expected : String) -> CheckState? {
  for result in evidence.checks {
    if result.name == expected {
      return Some(result.state)
    }
  }
  None
}

///|
fn count_owner_approvals(
  owners : Array[String],
  approvals : Array[String],
) -> Int {
  let mut count = 0
  if owners.is_empty() {
    return approvals.length()
  }
  for owner in owners {
    if contains_string(approvals, owner) {
      count = count + 1
    }
  }
  count
}

///|
fn add_finding(
  findings : Array[Finding],
  level : FindingLevel,
  code : String,
  path : String,
  message : String,
) -> Unit {
  findings.push(Finding::new(level, code, path, message))
}

///|
pub struct AuditReport {
  change_id : String
  status : GateStatus
  total_lines : Int
  decisions : Array[PathDecision]
  findings : Array[Finding]
} derive(Eq, @debug.Debug)

///|
pub fn AuditReport::change_id(self : AuditReport) -> String {
  self.change_id
}

///|
pub fn AuditReport::status(self : AuditReport) -> GateStatus {
  self.status
}

///|
pub fn AuditReport::total_lines(self : AuditReport) -> Int {
  self.total_lines
}

///|
pub fn AuditReport::decisions(self : AuditReport) -> Array[PathDecision] {
  self.decisions.copy()
}

///|
pub fn AuditReport::findings(self : AuditReport) -> Array[Finding] {
  self.findings.copy()
}

///|
pub fn AuditReport::has_code(self : AuditReport, code : String) -> Bool {
  for finding in self.findings {
    if finding.code == code {
      return true
    }
  }
  false
}

///|
fn change_policy_paths(change : Change) -> Array[String] {
  if change.kind == Rename && change.old_path != change.new_path {
    [change.old_path.unwrap(), change.new_path.unwrap()]
  } else {
    [change.policy_path()]
  }
}

///|
fn evaluate_path(
  policy : Policy,
  change : Change,
  path : String,
  evidence : Evidence,
  findings : Array[Finding],
) -> PathDecision {
  let decision = resolve_path(policy, path)
  if policy.require_owned && decision.owners.is_empty() {
    add_finding(
      findings,
      Blocking,
      "owner.unassigned",
      path,
      "no owner rule covers this path",
    )
  }
  let owner_approvals = count_owner_approvals(
    decision.owners,
    evidence.approvals,
  )
  if owner_approvals < decision.approvals {
    add_finding(
      findings,
      Attention,
      "approval.missing",
      path,
      "needs " +
      decision.approvals.to_string() +
      " owner approval(s), has " +
      owner_approvals.to_string(),
    )
  }
  if contains_kind(decision.forbidden, change.kind) {
    add_finding(
      findings,
      Blocking,
      "operation.forbidden",
      path,
      change.kind.to_text() + " is forbidden by a matching rule",
    )
  }
  match decision.max_lines {
    Some(limit) =>
      if change.changed_lines() > limit {
        add_finding(
          findings,
          Blocking,
          "budget.path.exceeded",
          path,
          change.changed_lines().to_string() +
          " changed lines exceed limit " +
          limit.to_string(),
        )
      }
    None => ()
  }
  if change.binary && !decision.allow_binary {
    add_finding(
      findings,
      Blocking,
      "binary.forbidden",
      path,
      "binary content is denied by a matching rule",
    )
  }
  for required in decision.checks {
    match check_state(evidence, required) {
      Some(Passed) => ()
      Some(Failed) =>
        add_finding(
          findings,
          Blocking,
          "check.failed",
          path,
          "required check " + required + " failed",
        )
      Some(Pending) =>
        add_finding(
          findings,
          Attention,
          "check.pending",
          path,
          "required check " + required + " is pending",
        )
      None =>
        add_finding(
          findings,
          Attention,
          "check.missing",
          path,
          "required check " + required + " has no result",
        )
    }
  }
  for required in decision.labels {
    if !contains_string(evidence.labels, required) {
      add_finding(
        findings,
        Attention,
        "label.missing",
        path,
        "required label " + required + " is absent",
      )
    }
  }
  if decision.release_note && !evidence.release_note {
    add_finding(
      findings,
      Attention,
      "release_note.missing",
      path,
      "a release note is required",
    )
  }
  decision
}

///|
pub fn evaluate(policy : Policy, changes : ChangeSet) -> AuditReport {
  let findings : Array[Finding] = []
  let decisions : Array[PathDecision] = []
  let evidence = changes.evidence
  let mut total_lines = 0
  for change in changes.changes {
    total_lines = total_lines + change.changed_lines()
    for path in change_policy_paths(change) {
      decisions.push(evaluate_path(policy, change, path, evidence, findings))
    }
  }
  match policy.max_total_lines {
    Some(limit) =>
      if total_lines > limit {
        add_finding(
          findings,
          Blocking,
          "budget.total.exceeded",
          "*",
          total_lines.to_string() +
          " changed lines exceed total limit " +
          limit.to_string(),
        )
      }
    None => ()
  }
  let mut status = GateStatus::Passed
  for finding in findings {
    match finding.level {
      Blocking => status = Rejected
      Attention => if status == GateStatus::Passed { status = Review }
    }
  }
  { change_id: changes.id, status, total_lines, decisions, findings }
}

///|
pub fn AuditReport::to_text(self : AuditReport) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "MOONCHANGE_REPORT 1\nID " +
    self.change_id +
    "\nSTATUS " +
    self.status.to_text() +
    "\nTOTAL_LINES " +
    self.total_lines.to_string(),
  )
  for decision in self.decisions {
    let owner_pattern = decision.owner_pattern.unwrap_or("-")
    output.write_string(
      "\nPATH " +
      decision.path +
      " owners=" +
      format_optional_csv(decision.owners) +
      " owner_pattern=" +
      owner_pattern +
      " approvals=" +
      decision.approvals.to_string() +
      " rules=" +
      format_optional_csv(decision.matched_rules),
    )
  }
  for finding in self.findings {
    output.write_string("\nFINDING " + finding.to_text())
  }
  output.to_string()
}
