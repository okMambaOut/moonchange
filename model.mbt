///|
pub(all) enum ChangeKind {
  Add
  Modify
  Delete
  Rename
  Copy
} derive(Eq, @debug.Debug)

///|
pub fn ChangeKind::to_text(self : ChangeKind) -> String {
  match self {
    Add => "add"
    Modify => "modify"
    Delete => "delete"
    Rename => "rename"
    Copy => "copy"
  }
}

///|
pub fn ChangeKind::parse(value : String) -> ChangeKind? {
  match value {
    "add" => Some(Add)
    "modify" => Some(Modify)
    "delete" => Some(Delete)
    "rename" => Some(Rename)
    "copy" => Some(Copy)
    _ => None
  }
}

///|
pub struct Change {
  kind : ChangeKind
  old_path : String?
  new_path : String?
  additions : Int
  deletions : Int
  binary : Bool
} derive(Eq, @debug.Debug)

///|
pub fn Change::new(
  kind : ChangeKind,
  old_path : String?,
  new_path : String?,
  additions : Int,
  deletions : Int,
  binary? : Bool = false,
) -> Result[Change, Diagnostic] {
  if additions < 0 || deletions < 0 {
    return Err(
      Diagnostic::new(
        "change.lines.negative",
        "change",
        "line counts cannot be negative",
        "non-negative additions and deletions",
        additions.to_string() + "/" + deletions.to_string(),
      ),
    )
  }
  if additions > 10000000 || deletions > 10000000 {
    return Err(
      Diagnostic::new(
        "change.lines.limit",
        "change",
        "line count exceeds the safety limit",
        "at most 10000000 per side",
        additions.to_string() + "/" + deletions.to_string(),
      ),
    )
  }
  let old_required = kind != Add
  let new_required = kind != Delete
  if old_required && old_path is None {
    return Err(
      Diagnostic::new(
        "change.old_path.required", "change.old_path", "operation needs an old path",
        "safe relative path", "missing",
      ),
    )
  }
  if !old_required && old_path is Some(_) {
    return Err(
      Diagnostic::new(
        "change.old_path.unexpected",
        "change.old_path",
        "add operation cannot have an old path",
        "missing old path",
        old_path.unwrap(),
      ),
    )
  }
  if new_required && new_path is None {
    return Err(
      Diagnostic::new(
        "change.new_path.required", "change.new_path", "operation needs a new path",
        "safe relative path", "missing",
      ),
    )
  }
  if !new_required && new_path is Some(_) {
    return Err(
      Diagnostic::new(
        "change.new_path.unexpected",
        "change.new_path",
        "delete operation cannot have a new path",
        "missing new path",
        new_path.unwrap(),
      ),
    )
  }
  if (kind == Modify || kind == Copy) && old_path != new_path && kind == Modify {
    return Err(
      Diagnostic::new(
        "change.modify.path",
        "change",
        "modify operation must keep the same path",
        old_path.unwrap_or("missing"),
        new_path.unwrap_or("missing"),
      ),
    )
  }
  if kind == Rename && old_path == new_path {
    return Err(
      Diagnostic::new(
        "change.rename.same_path",
        "change",
        "rename operation must change path",
        "different old and new paths",
        old_path.unwrap_or("missing"),
      ),
    )
  }
  match old_path {
    Some(value) =>
      if !is_safe_repo_path(value) {
        return Err(
          Diagnostic::new(
            "change.path.unsafe", "change.old_path", "path is not a normalized repository-relative path",
            "relative forward-slash path without dot segments", value,
          ),
        )
      }
    None => ()
  }
  match new_path {
    Some(value) =>
      if !is_safe_repo_path(value) {
        return Err(
          Diagnostic::new(
            "change.path.unsafe", "change.new_path", "path is not a normalized repository-relative path",
            "relative forward-slash path without dot segments", value,
          ),
        )
      }
    None => ()
  }
  Ok({ kind, old_path, new_path, additions, deletions, binary })
}

///|
pub fn Change::kind(self : Change) -> ChangeKind {
  self.kind
}

///|
pub fn Change::old_path(self : Change) -> String? {
  self.old_path
}

///|
pub fn Change::new_path(self : Change) -> String? {
  self.new_path
}

///|
pub fn Change::additions(self : Change) -> Int {
  self.additions
}

///|
pub fn Change::deletions(self : Change) -> Int {
  self.deletions
}

///|
pub fn Change::is_binary(self : Change) -> Bool {
  self.binary
}

///|
pub fn Change::changed_lines(self : Change) -> Int {
  self.additions + self.deletions
}

///|
pub fn Change::policy_path(self : Change) -> String {
  match self.new_path {
    Some(path) => path
    None => self.old_path.unwrap()
  }
}

///|
pub(all) enum CheckState {
  Passed
  Failed
  Pending
} derive(Eq, @debug.Debug)

///|
pub fn CheckState::to_text(self : CheckState) -> String {
  match self {
    Passed => "passed"
    Failed => "failed"
    Pending => "pending"
  }
}

///|
pub fn CheckState::parse(value : String) -> CheckState? {
  match value {
    "passed" => Some(Passed)
    "failed" => Some(Failed)
    "pending" => Some(Pending)
    _ => None
  }
}

///|
pub struct CheckResult {
  name : String
  state : CheckState
} derive(Eq, @debug.Debug)

///|
pub fn CheckResult::new(name : String, state : CheckState) -> CheckResult {
  { name, state }
}

///|
pub fn CheckResult::name(self : CheckResult) -> String {
  self.name
}

///|
pub fn CheckResult::state(self : CheckResult) -> CheckState {
  self.state
}

///|
pub struct Evidence {
  actor : String
  approvals : Array[String]
  checks : Array[CheckResult]
  labels : Array[String]
  release_note : Bool
} derive(Eq, @debug.Debug)

///|
pub fn Evidence::new(
  actor : String,
  approvals : Array[String],
  checks : Array[CheckResult],
  labels : Array[String],
  release_note? : Bool = false,
) -> Evidence {
  {
    actor,
    approvals: approvals.copy(),
    checks: checks.copy(),
    labels: labels.copy(),
    release_note,
  }
}

///|
pub fn Evidence::actor(self : Evidence) -> String {
  self.actor
}

///|
pub fn Evidence::approvals(self : Evidence) -> Array[String] {
  self.approvals.copy()
}

///|
pub fn Evidence::checks(self : Evidence) -> Array[CheckResult] {
  self.checks.copy()
}

///|
pub fn Evidence::labels(self : Evidence) -> Array[String] {
  self.labels.copy()
}

///|
pub fn Evidence::has_release_note(self : Evidence) -> Bool {
  self.release_note
}

///|
pub struct ChangeSet {
  id : String
  changes : Array[Change]
  evidence : Evidence
} derive(Eq, @debug.Debug)

///|
pub fn ChangeSet::new(
  id : String,
  changes : Array[Change],
  evidence : Evidence,
) -> Result[ChangeSet, Diagnostic] {
  if !is_identifier(id) {
    return Err(
      Diagnostic::new(
        "changeset.id.invalid", "changeset.id", "change-set identifier is invalid",
        "1-64 letters, digits, dot, underscore, or hyphen", id,
      ),
    )
  }
  if changes.is_empty() {
    return Err(
      Diagnostic::new(
        "changeset.empty", "changeset.changes", "change set contains no changes",
        "at least one change", "none",
      ),
    )
  }
  if changes.length() > 10000 {
    return Err(
      Diagnostic::new(
        "changeset.limit",
        "changeset.changes",
        "change set exceeds the safety limit",
        "at most 10000 changes",
        changes.length().to_string(),
      ),
    )
  }
  Ok({ id, changes: changes.copy(), evidence })
}

///|
pub fn ChangeSet::id(self : ChangeSet) -> String {
  self.id
}

///|
pub fn ChangeSet::changes(self : ChangeSet) -> Array[Change] {
  self.changes.copy()
}

///|
pub fn ChangeSet::evidence(self : ChangeSet) -> Evidence {
  self.evidence
}
