///|
pub struct StringDelta {
  added : Array[String]
  removed : Array[String]
} derive(Eq, @debug.Debug)

///|
pub fn StringDelta::added(self : StringDelta) -> Array[String] {
  self.added.copy()
}

///|
pub fn StringDelta::removed(self : StringDelta) -> Array[String] {
  self.removed.copy()
}

///|
pub fn StringDelta::changed(self : StringDelta) -> Bool {
  !self.added.is_empty() || !self.removed.is_empty()
}

///|
fn string_delta(before : Array[String], after : Array[String]) -> StringDelta {
  let added : Array[String] = []
  let removed : Array[String] = []
  for value in after {
    if !contains_string(before, value) {
      added.push(value)
    }
  }
  for value in before {
    if !contains_string(after, value) {
      removed.push(value)
    }
  }
  added.sort_by(fn(left, right) { left.lexical_compare(right) })
  removed.sort_by(fn(left, right) { left.lexical_compare(right) })
  { added, removed }
}

///|
fn kind_texts(values : Array[ChangeKind]) -> Array[String] {
  values.map(fn(kind) { kind.to_text() })
}

///|
pub struct PathPolicyDelta {
  path : String
  before : PathDecision
  after : PathDecision
  owners : StringDelta
  rules : StringDelta
  checks : StringDelta
  labels : StringDelta
  forbidden : StringDelta
} derive(Eq, @debug.Debug)

///|
pub fn PathPolicyDelta::path(self : PathPolicyDelta) -> String {
  self.path
}

///|
pub fn PathPolicyDelta::before(self : PathPolicyDelta) -> PathDecision {
  self.before
}

///|
pub fn PathPolicyDelta::after(self : PathPolicyDelta) -> PathDecision {
  self.after
}

///|
pub fn PathPolicyDelta::owners(self : PathPolicyDelta) -> StringDelta {
  self.owners
}

///|
pub fn PathPolicyDelta::rules(self : PathPolicyDelta) -> StringDelta {
  self.rules
}

///|
pub fn PathPolicyDelta::checks(self : PathPolicyDelta) -> StringDelta {
  self.checks
}

///|
pub fn PathPolicyDelta::labels(self : PathPolicyDelta) -> StringDelta {
  self.labels
}

///|
pub fn PathPolicyDelta::forbidden(self : PathPolicyDelta) -> StringDelta {
  self.forbidden
}

///|
pub fn PathPolicyDelta::changed(self : PathPolicyDelta) -> Bool {
  self.before != self.after
}

///|
pub struct PolicyComparison {
  paths : Array[PathPolicyDelta]
} derive(Eq, @debug.Debug)

///|
pub fn PolicyComparison::paths(
  self : PolicyComparison,
) -> Array[PathPolicyDelta] {
  self.paths.copy()
}

///|
pub fn PolicyComparison::changed_count(self : PolicyComparison) -> Int {
  let mut count = 0
  for path in self.paths {
    if path.changed() {
      count = count + 1
    }
  }
  count
}

///|
pub fn compare_policies(
  before : Policy,
  after : Policy,
  paths : Array[String],
) -> Result[PolicyComparison, Diagnostic] {
  if paths.is_empty() || paths.length() > 10000 {
    return Err(
      Diagnostic::new(
        "compare.paths.limit",
        "paths",
        "path list is empty or exceeds the limit",
        "1 through 10000 paths",
        paths.length().to_string(),
      ),
    )
  }
  let seen : Array[String] = []
  let deltas : Array[PathPolicyDelta] = []
  for index, path in paths {
    if contains_string(seen, path) {
      return Err(
        Diagnostic::new(
          "compare.path.duplicate",
          "paths[" + index.to_string() + "]",
          "path appears more than once",
          "unique path",
          path,
        ),
      )
    }
    let before_decision = match before.explain(path) {
      Ok(value) => value
      Err(_) =>
        return Err(
          Diagnostic::new(
            "compare.path.unsafe",
            "paths[" + index.to_string() + "]",
            "comparison path is unsafe",
            "safe repository-relative path",
            path,
          ),
        )
    }
    let after_decision = after.explain(path).unwrap()
    seen.push(path)
    deltas.push({
      path,
      before: before_decision,
      after: after_decision,
      owners: string_delta(before_decision.owners, after_decision.owners),
      rules: string_delta(
        before_decision.matched_rules,
        after_decision.matched_rules,
      ),
      checks: string_delta(before_decision.checks, after_decision.checks),
      labels: string_delta(before_decision.labels, after_decision.labels),
      forbidden: string_delta(
        kind_texts(before_decision.forbidden),
        kind_texts(after_decision.forbidden),
      ),
    })
  }
  Ok({ paths: deltas })
}

///|
fn delta_text(name : String, delta : StringDelta) -> String {
  name +
  "+=" +
  format_optional_csv(delta.added) +
  " " +
  name +
  "-=" +
  format_optional_csv(delta.removed)
}

///|
pub fn PolicyComparison::to_text(self : PolicyComparison) -> String {
  let output = StringBuilder()
  output.write_string(
    "MOONCHANGE_COMPARE 1\nPATHS " +
    self.paths.length().to_string() +
    "\nCHANGED " +
    self.changed_count().to_string(),
  )
  for delta in self.paths {
    let state = if delta.changed() { "changed" } else { "unchanged" }
    output.write_string(
      "\nPATH " +
      delta.path +
      " " +
      state +
      "\n  " +
      delta_text("owners", delta.owners) +
      "\n  approvals=" +
      delta.before.approvals.to_string() +
      "=>" +
      delta.after.approvals.to_string() +
      "\n  " +
      delta_text("checks", delta.checks) +
      "\n  " +
      delta_text("labels", delta.labels) +
      "\n  " +
      delta_text("forbid", delta.forbidden) +
      "\n  max_lines=" +
      delta.before.max_lines.map(fn(value) { value.to_string() }).unwrap_or("-") +
      "=>" +
      delta.after.max_lines.map(fn(value) { value.to_string() }).unwrap_or("-") +
      "\n  release_note=" +
      (if delta.before.release_note { "yes" } else { "no" }) +
      "=>" +
      (if delta.after.release_note { "yes" } else { "no" }) +
      "\n  binary=" +
      (if delta.before.allow_binary { "allow" } else { "deny" }) +
      "=>" +
      (if delta.after.allow_binary { "allow" } else { "deny" }),
    )
  }
  output.to_string()
}
