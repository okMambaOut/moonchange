///|
test "construct valid repository changes" {
  let added = Change::new(Add, None, Some("src/new.mbt"), 10, 0).unwrap()
  assert_true(added.kind() is Add)
  assert_eq(added.policy_path(), "src/new.mbt")
  assert_eq(added.changed_lines(), 10)
  let renamed = Change::new(Rename, Some("old.mbt"), Some("new.mbt"), 2, 1).unwrap()
  assert_true(renamed.kind() is Rename)
  assert_eq(renamed.old_path(), Some("old.mbt"))
  assert_eq(renamed.new_path(), Some("new.mbt"))
}

///|
test "reject impossible operations unsafe paths and invalid counts" {
  assert_eq(
    Change::new(Add, Some("old"), Some("new"), 1, 0).unwrap_err().code(),
    "change.old_path.unexpected",
  )
  assert_eq(
    Change::new(Delete, Some("old"), Some("new"), 0, 1).unwrap_err().code(),
    "change.new_path.unexpected",
  )
  assert_eq(
    Change::new(Modify, Some("a"), Some("b"), 1, 1).unwrap_err().code(),
    "change.modify.path",
  )
  assert_eq(
    Change::new(Rename, Some("a"), Some("a"), 1, 1).unwrap_err().code(),
    "change.rename.same_path",
  )
  assert_eq(
    Change::new(Add, None, Some("../escape"), 1, 0).unwrap_err().code(),
    "change.path.unsafe",
  )
  assert_eq(
    Change::new(Add, None, Some("safe"), -1, 0).unwrap_err().code(),
    "change.lines.negative",
  )
}

///|
test "change sets require stable identifiers and content" {
  let evidence = Evidence::new("@author", [], [], [])
  assert_eq(
    ChangeSet::new(
      "bad id",
      [Change::new(Add, None, Some("x"), 1, 0).unwrap()],
      evidence,
    )
    .unwrap_err()
    .code(),
    "changeset.id.invalid",
  )
  assert_eq(
    ChangeSet::new("PR-42", [], evidence).unwrap_err().code(),
    "changeset.empty",
  )
}
