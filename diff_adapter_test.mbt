///|
let diff_fixture = "diff --git a/src/main.mbt b/src/main.mbt\nindex 1111111..2222222 100644\n--- a/src/main.mbt\n+++ b/src/main.mbt\n@@ -1 +1,2 @@\n-old\n+new\n+more\ndiff --git a/docs/new.md b/docs/new.md\nnew file mode 100644\n--- /dev/null\n+++ b/docs/new.md\n@@ -0,0 +1 @@\n+hello\ndiff --git a/old.mbt b/new.mbt\nsimilarity index 100%\nrename from old.mbt\nrename to new.mbt"

///|
test "adapt upstream patch metadata into changes" {
  let changes = changes_from_unified_diff(diff_fixture).unwrap()
  assert_eq(changes.length(), 3)
  assert_eq(changes[0].kind(), Modify)
  assert_eq(changes[0].changed_lines(), 3)
  assert_eq(changes[1].kind(), Add)
  assert_eq(changes[1].new_path(), Some("docs/new.md"))
  assert_eq(changes[2].kind(), Rename)
  assert_eq(changes[2].old_path(), Some("old.mbt"))
  assert_eq(changes[2].new_path(), Some("new.mbt"))
}

///|
test "diff adapter rejects empty malformed and unsafe metadata" {
  assert_eq(
    changes_from_unified_diff("").unwrap_err().code(),
    "diff.input.limit",
  )
  assert_eq(
    changes_from_unified_diff("not a diff").unwrap_err().code(),
    "diff.patch.none",
  )
  assert_eq(
    changes_from_unified_diff(
      "diff --git a/../secret b/../secret\n--- a/../secret\n+++ b/../secret\n@@ -1 +1 @@\n-old\n+new",
    )
    .unwrap_err()
    .code(),
    "diff.patch.invalid",
  )
}

///|
test "adapted diff can enter the governance engine" {
  let evidence = Evidence::new(
    "@alice",
    ["@maintainers"],
    [CheckResult::new("unit", CheckState::Passed)],
    ["code"],
  )
  let changes = change_set_from_unified_diff("PR-DIFF", evidence, diff_fixture).unwrap()
  let policy = parse_policy(
    "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 require_owned=yes\nOWNER **/* @maintainers\nRULE source src/** checks=unit labels=code",
  ).unwrap()
  assert_eq(evaluate(policy, changes).status(), GateStatus::Passed)
}
