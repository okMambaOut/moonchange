///|
pub struct OwnerRule {
  pattern : PathGlob
  owners : Array[String]
} derive(Eq, @debug.Debug)

///|
pub fn OwnerRule::new(
  pattern : PathGlob,
  owners : Array[String],
) -> Result[OwnerRule, Diagnostic] {
  if owners.is_empty() {
    return Err(
      Diagnostic::new(
        "policy.owner.empty", "owner.owners", "owner rule has no owners", "at least one @owner",
        "none",
      ),
    )
  }
  let normalized : Array[String] = []
  for index, owner in owners {
    if !is_principal(owner) {
      return Err(
        Diagnostic::new(
          "policy.principal.invalid",
          "owner.owners[" + index.to_string() + "]",
          "owner principal is invalid",
          "@ followed by letters, digits, dot, underscore, slash, or hyphen",
          owner,
        ),
      )
    }
    push_unique_string(normalized, owner)
  }
  Ok({ pattern, owners: normalized, })
}

///|
pub fn OwnerRule::pattern(self : OwnerRule) -> PathGlob {
  self.pattern
}

///|
pub fn OwnerRule::owners(self : OwnerRule) -> Array[String] {
  self.owners.copy()
}

///|
pub struct GovernanceRule {
  name : String
  pattern : PathGlob
  approvals : Int
  checks : Array[String]
  labels : Array[String]
  forbidden : Array[ChangeKind]
  max_lines : Int?
  release_note : Bool
  allow_binary : Bool
} derive(Eq, @debug.Debug)

///|
pub fn GovernanceRule::new(
  name : String,
  pattern : PathGlob,
  approvals? : Int = 0,
  checks? : Array[String] = [],
  labels? : Array[String] = [],
  forbidden? : Array[ChangeKind] = [],
  max_lines? : Int? = None,
  release_note? : Bool = false,
  allow_binary? : Bool = true,
) -> Result[GovernanceRule, Diagnostic] {
  if !is_simple_name(name) {
    return Err(
      Diagnostic::new(
        "policy.rule.name", "rule.name", "rule name is invalid", "1-64 letters, digits, dot, underscore, or hyphen",
        name,
      ),
    )
  }
  if approvals < 0 || approvals > 20 {
    return Err(
      Diagnostic::new(
        "policy.approvals.limit",
        "rule.approvals",
        "approval count is outside the limit",
        "0 through 20",
        approvals.to_string(),
      ),
    )
  }
  match max_lines {
    Some(value) =>
      if value < 0 || value > 10000000 {
        return Err(
          Diagnostic::new(
            "policy.lines.limit",
            "rule.max_lines",
            "line budget is outside the limit",
            "0 through 10000000",
            value.to_string(),
          ),
        )
      }
    None => ()
  }
  let normalized_checks = match normalize_names(checks, "rule.checks") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let normalized_labels = match normalize_names(labels, "rule.labels") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let normalized_forbidden : Array[ChangeKind] = []
  for kind in forbidden {
    if !contains_kind(normalized_forbidden, kind) {
      normalized_forbidden.push(kind)
    }
  }
  Ok({
    name,
    pattern,
    approvals,
    checks: normalized_checks,
    labels: normalized_labels,
    forbidden: normalized_forbidden,
    max_lines,
    release_note,
    allow_binary,
  })
}

///|
pub fn GovernanceRule::name(self : GovernanceRule) -> String {
  self.name
}

///|
pub fn GovernanceRule::pattern(self : GovernanceRule) -> PathGlob {
  self.pattern
}

///|
pub fn GovernanceRule::approvals(self : GovernanceRule) -> Int {
  self.approvals
}

///|
pub fn GovernanceRule::checks(self : GovernanceRule) -> Array[String] {
  self.checks.copy()
}

///|
pub fn GovernanceRule::labels(self : GovernanceRule) -> Array[String] {
  self.labels.copy()
}

///|
pub fn GovernanceRule::forbidden(self : GovernanceRule) -> Array[ChangeKind] {
  self.forbidden.copy()
}

///|
pub fn GovernanceRule::max_lines(self : GovernanceRule) -> Int? {
  self.max_lines
}

///|
pub fn GovernanceRule::requires_release_note(self : GovernanceRule) -> Bool {
  self.release_note
}

///|
pub fn GovernanceRule::allows_binary(self : GovernanceRule) -> Bool {
  self.allow_binary
}

///|
pub struct Policy {
  default_approvals : Int
  max_total_lines : Int?
  require_owned : Bool
  owner_rules : Array[OwnerRule]
  rules : Array[GovernanceRule]
} derive(Eq, @debug.Debug)

///|
pub fn Policy::new(
  default_approvals? : Int = 1,
  max_total_lines? : Int? = None,
  require_owned? : Bool = true,
  owner_rules? : Array[OwnerRule] = [],
  rules? : Array[GovernanceRule] = [],
) -> Result[Policy, Diagnostic] {
  if default_approvals < 0 || default_approvals > 20 {
    return Err(
      Diagnostic::new(
        "policy.approvals.limit",
        "policy.default_approvals",
        "default approval count is outside the limit",
        "0 through 20",
        default_approvals.to_string(),
      ),
    )
  }
  match max_total_lines {
    Some(value) =>
      if value < 0 || value > 100000000 {
        return Err(
          Diagnostic::new(
            "policy.lines.limit",
            "policy.max_total_lines",
            "total line budget is outside the limit",
            "0 through 100000000",
            value.to_string(),
          ),
        )
      }
    None => ()
  }
  let names : Array[String] = []
  for index, rule in rules {
    if contains_string(names, rule.name) {
      return Err(
        Diagnostic::new(
          "policy.rule.duplicate",
          "policy.rules[" + index.to_string() + "].name",
          "rule name appears more than once",
          "unique rule name",
          rule.name,
        ),
      )
    }
    names.push(rule.name)
  }
  Ok({
    default_approvals,
    max_total_lines,
    require_owned,
    owner_rules: owner_rules.copy(),
    rules: rules.copy(),
  })
}

///|
pub fn Policy::default_approvals(self : Policy) -> Int {
  self.default_approvals
}

///|
pub fn Policy::max_total_lines(self : Policy) -> Int? {
  self.max_total_lines
}

///|
pub fn Policy::requires_owned_paths(self : Policy) -> Bool {
  self.require_owned
}

///|
pub fn Policy::owner_rules(self : Policy) -> Array[OwnerRule] {
  self.owner_rules.copy()
}

///|
pub fn Policy::rules(self : Policy) -> Array[GovernanceRule] {
  self.rules.copy()
}

///|
fn contains_kind(values : Array[ChangeKind], expected : ChangeKind) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}
