///|
fn patch_kind(info : @bit_apply.PatchInfo) -> ChangeKind {
  if info.is_rename {
    Rename
  } else if info.is_copy {
    Copy
  } else if info.is_new {
    Add
  } else if info.is_delete {
    Delete
  } else {
    Modify
  }
}

///|
fn patch_paths(
  info : @bit_apply.PatchInfo,
  kind : ChangeKind,
) -> (String?, String?) {
  match kind {
    Add => (None, Some(info.new_name))
    Delete => (Some(info.old_name), None)
    Modify => {
      let path = if info.new_name.is_empty() {
        info.old_name
      } else {
        info.new_name
      }
      (Some(path), Some(path))
    }
    Rename | Copy => (Some(info.old_name), Some(info.new_name))
  }
}

///|
pub fn changes_from_unified_diff(
  source : String,
) -> Result[Array[Change], Diagnostic] {
  if source.is_empty() || source.length() > 16777216 {
    return Err(
      Diagnostic::new(
        "diff.input.limit",
        "diff",
        "diff is empty or exceeds the adapter limit",
        "1 through 16777216 characters",
        source.length().to_string(),
      ),
    )
  }
  let patches = @bit_apply.parse_patches(source)
  if patches.is_empty() {
    return Err(
      Diagnostic::new(
        "diff.patch.none", "diff", "upstream parser found no file patches", "at least one diff header",
        "none",
      ),
    )
  }
  let changes : Array[Change] = []
  for index, info in patches {
    let kind = patch_kind(info)
    let (old_path, new_path) = patch_paths(info, kind)
    let change = match
      Change::new(kind, old_path, new_path, info.additions, info.deletions) {
      Ok(value) => value
      Err(error) =>
        return Err(
          Diagnostic::new(
            "diff.patch.invalid",
            "patches[" + index.to_string() + "]",
            "upstream patch metadata cannot form a safe MoonChange change",
            error.expected(),
            error.actual(),
          ),
        )
    }
    changes.push(change)
  }
  Ok(changes)
}

///|
pub fn change_set_from_unified_diff(
  id : String,
  evidence : Evidence,
  source : String,
) -> Result[ChangeSet, Diagnostic] {
  let changes = match changes_from_unified_diff(source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ChangeSet::new(id, changes, evidence)
}
