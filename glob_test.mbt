///|
test "compile and match repository path globs" {
  let source = PathGlob::compile("src/**/test_?.mbt").unwrap()
  assert_true(source.matches("src/test_a.mbt"))
  assert_true(source.matches("src/core/test_1.mbt"))
  assert_true(source.matches("src/a/b/test_x.mbt"))
  assert_false(source.matches("src/a/test_long.mbt"))
  assert_false(source.matches("docs/test_a.mbt"))
  assert_false(source.matches("../src/test_a.mbt"))
}

///|
test "single star never crosses a slash and double star may match zero segments" {
  let single = PathGlob::compile("docs/*.md").unwrap()
  assert_true(single.matches("docs/readme.md"))
  assert_false(single.matches("docs/guides/readme.md"))
  let recursive = PathGlob::compile("**/*.md").unwrap()
  assert_true(recursive.matches("readme.md"))
  assert_true(recursive.matches("docs/guides/readme.md"))
}

///|
test "literal-heavy globs have greater specificity" {
  let broad = PathGlob::compile("**/*.mbt").unwrap()
  let narrow = PathGlob::compile("src/security/*.mbt").unwrap()
  assert_true(narrow.specificity() > broad.specificity())
  assert_eq(narrow.source(), "src/security/*.mbt")
}

///|
test "reject invalid and unsupported glob syntax" {
  assert_eq(
    PathGlob::compile("/src/**").unwrap_err().code(),
    "glob.path.invalid",
  )
  assert_eq(
    PathGlob::compile("src/**tail").unwrap_err().code(),
    "glob.double_star.position",
  )
  assert_eq(
    PathGlob::compile("src/[ab].mbt").unwrap_err().code(),
    "glob.character.unsupported",
  )
  assert_eq(
    PathGlob::compile("src//x").unwrap_err().code(),
    "glob.segment.invalid",
  )
}
