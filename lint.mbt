///|
pub(all) enum LintLevel {
  LintInfo
  LintWarning
  LintError
} derive(Eq, @debug.Debug)

///|
pub fn LintLevel::to_text(self : LintLevel) -> String {
  match self {
    LintInfo => "info"
    LintWarning => "warning"
    LintError => "error"
  }
}

///|
pub struct LintIssue {
  level : LintLevel
  code : String
  subject : String
  message : String
} derive(Eq, @debug.Debug)

///|
pub fn LintIssue::level(self : LintIssue) -> LintLevel {
  self.level
}

///|
pub fn LintIssue::code(self : LintIssue) -> String {
  self.code
}

///|
pub fn LintIssue::subject(self : LintIssue) -> String {
  self.subject
}

///|
pub fn LintIssue::message(self : LintIssue) -> String {
  self.message
}

///|
pub fn LintIssue::to_text(self : LintIssue) -> String {
  self.level.to_text() +
  " " +
  self.code +
  " " +
  self.subject +
  ": " +
  self.message
}

///|
pub struct LintReport {
  issues : Array[LintIssue]
} derive(Eq, @debug.Debug)

///|
pub fn LintReport::issues(self : LintReport) -> Array[LintIssue] {
  self.issues.copy()
}

///|
pub fn LintReport::is_clean(self : LintReport) -> Bool {
  self.issues.is_empty()
}

///|
pub fn LintReport::has_errors(self : LintReport) -> Bool {
  for issue in self.issues {
    if issue.level == LintError {
      return true
    }
  }
  false
}

///|
pub fn LintReport::has_code(self : LintReport, code : String) -> Bool {
  for issue in self.issues {
    if issue.code == code {
      return true
    }
  }
  false
}

///|
fn rule_has_obligation(rule : GovernanceRule) -> Bool {
  rule.approvals > 0 ||
  !rule.checks.is_empty() ||
  !rule.labels.is_empty() ||
  !rule.forbidden.is_empty() ||
  rule.max_lines is Some(_) ||
  rule.release_note ||
  !rule.allow_binary
}

///|
fn owner_has_global_coverage(rule : OwnerRule) -> Bool {
  rule.pattern.source() == "**" || rule.pattern.source() == "**/*"
}

///|
pub fn lint_policy(policy : Policy) -> LintReport {
  let issues : Array[LintIssue] = []
  let mut global_owner = false
  for index, owner in policy.owner_rules {
    if owner_has_global_coverage(owner) {
      global_owner = true
    }
    for later_index = index + 1
        later_index < policy.owner_rules.length()
        later_index = later_index + 1 {
      let later = policy.owner_rules[later_index]
      if owner.pattern.source() == later.pattern.source() {
        issues.push({
          level: LintWarning,
          code: "lint.owner.overridden",
          subject: owner.pattern.source(),
          message: "a later owner rule with the same pattern always wins",
        })
        break
      }
    }
  }
  if policy.require_owned && !global_owner {
    issues.push({
      level: LintWarning,
      code: "lint.owner.no_global_coverage",
      subject: "OWNER",
      message: "ownership is required but no ** or **/* fallback owner exists",
    })
  }
  if policy.owner_rules.is_empty() && policy.require_owned {
    issues.push({
      level: LintError,
      code: "lint.owner.none",
      subject: "OWNER",
      message: "every change will be rejected because ownership is required and no owner rules exist",
    })
  }
  if policy.rules.is_empty() {
    issues.push({
      level: LintInfo,
      code: "lint.rule.none",
      subject: "RULE",
      message: "the policy relies only on defaults and ownership",
    })
  }
  for rule in policy.rules {
    if !rule_has_obligation(rule) {
      issues.push({
        level: LintWarning,
        code: "lint.rule.empty",
        subject: rule.name,
        message: "the rule matches paths but adds no governance obligation",
      })
    }
    if rule.approvals > 0 && policy.owner_rules.is_empty() {
      issues.push({
        level: LintWarning,
        code: "lint.approval.unscoped",
        subject: rule.name,
        message: "approval quorum has no owner rules and therefore accepts any principal",
      })
    }
  }
  LintReport::{ issues, }
}

///|
pub fn LintReport::to_text(self : LintReport) -> String {
  let output = StringBuilder()
  output.write_string("MOONCHANGE_LINT 1")
  if self.issues.is_empty() {
    output.write_string("\nCLEAN yes")
  } else {
    output.write_string("\nCLEAN no")
    for issue in self.issues {
      output.write_string("\nISSUE " + issue.to_text())
    }
  }
  output.to_string()
}

///|
pub fn PathDecision::to_text(self : PathDecision) -> String {
  let output = StringBuilder()
  let max_lines = match self.max_lines {
    Some(value) => value.to_string()
    None => "-"
  }
  let release_note = if self.release_note { "yes" } else { "no" }
  let binary = if self.allow_binary { "allow" } else { "deny" }
  let forbidden = self.forbidden.map(fn(kind) { kind.to_text() })
  output.write_string(
    "MOONCHANGE_EXPLAIN 1\nPATH " +
    self.path +
    "\nOWNERS " +
    format_optional_csv(self.owners) +
    "\nOWNER_PATTERN " +
    self.owner_pattern.unwrap_or("-") +
    "\nRULES " +
    format_optional_csv(self.matched_rules) +
    "\nAPPROVALS " +
    self.approvals.to_string() +
    "\nCHECKS " +
    format_optional_csv(self.checks) +
    "\nLABELS " +
    format_optional_csv(self.labels) +
    "\nFORBID " +
    format_optional_csv(forbidden) +
    "\nMAX_LINES " +
    max_lines +
    "\nRELEASE_NOTE " +
    release_note +
    "\nBINARY " +
    binary,
  )
  output.to_string()
}
