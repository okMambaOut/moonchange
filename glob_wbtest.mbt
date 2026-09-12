///|
// Independent, deliberately small recursive oracle: enumerate wildcard choices
// rather than using the production dynamic-programming recurrence.
fn reference_segment(
  pattern : String,
  value : String,
  p : Int,
  v : Int,
) -> Bool {
  if p == pattern.length() {
    return v == value.length()
  }
  if pattern[p] == '*' {
    for end = v; end <= value.length(); end = end + 1 {
      if reference_segment(pattern, value, p + 1, end) {
        return true
      }
    }
    return false
  }
  v < value.length() &&
  (pattern[p] == '?' || pattern[p] == value[v]) &&
  reference_segment(pattern, value, p + 1, v + 1)
}

///|
fn reference_path(
  pattern : Array[String],
  value : Array[String],
  p : Int,
  v : Int,
) -> Bool {
  if p == pattern.length() {
    return v == value.length()
  }
  if pattern[p] == "**" {
    for end = v; end <= value.length(); end = end + 1 {
      if reference_path(pattern, value, p + 1, end) {
        return true
      }
    }
    return false
  }
  v < value.length() &&
  reference_segment(pattern[p], value[v], 0, 0) &&
  reference_path(pattern, value, p + 1, v + 1)
}

///|
fn generated_words(
  alphabet : Array[String],
  depth : Int,
  separator : String,
) -> Array[String] {
  let all = [""]
  let mut level = [""]
  for i = 0; i < depth; i = i + 1 {
    let next : Array[String] = []
    for prefix in level {
      for token in alphabet {
        let word = if prefix.is_empty() {
          token
        } else {
          prefix + separator + token
        }
        next.push(word)
        all.push(word)
      }
    }
    level = next
  }
  all
}

///|
test "segment rolling state agrees with 10571 exhaustive oracle cases" {
  let patterns = generated_words(["a", "b", "*", "?"], 4, "")
  let values = generated_words(["a", "b"], 4, "")
  let mut cases = 0
  for pattern in patterns {
    for value in values {
      assert_eq(
        segment_matches(pattern, value),
        reference_segment(pattern, value, 0, 0),
      )
      cases = cases + 1
    }
  }
  assert_eq(cases, 10571)
}

///|
test "path rolling state agrees with 2520 exhaustive oracle cases" {
  let patterns = generated_words(["a", "b", "*", "**"], 3, "/")
  let values = generated_words(["a", "b"], 4, "/")
  let mut cases = 0
  for pattern in patterns {
    if pattern.is_empty() {
      continue
    }
    let glob = PathGlob::compile(pattern).unwrap()
    let parts = pattern.split("/").map(fn(s) { s.to_owned() }).collect()
    for value in values {
      if value.is_empty() {
        continue
      }
      let segments = value.split("/").map(fn(s) { s.to_owned() }).collect()
      assert_eq(glob.matches(value), reference_path(parts, segments, 0, 0))
      cases = cases + 1
    }
  }
  assert_eq(cases, 2520)
}

///|
test "maximum length and maximum depth paths preserve bounded matching" {
  let mut literal = ""
  let mut stars = ""
  for i = 0; i < 1024; i = i + 1 {
    literal = literal + "a"
    stars = stars + (if i % 2 == 0 { "a" } else { "*" })
  }
  assert_true(PathGlob::compile(stars).unwrap().matches(literal))
  assert_true(PathGlob::compile(literal).unwrap().matches(literal))
  assert_false(PathGlob::compile("*").unwrap().matches(literal + "a"))
  assert_true(PathGlob::compile(stars + "a") is Err(_))
  let mut deep = "a"
  for i = 1; i < 512; i = i + 1 {
    deep = deep + "/a"
  }
  assert_true(PathGlob::compile(deep).unwrap().matches(deep))
  assert_true(PathGlob::compile("**/**/a/**").unwrap().matches(deep))
  assert_false(PathGlob::compile("**/b").unwrap().matches(deep))
}

///|
test "glob regression empty consumption unicode and unsafe paths" {
  for
    pair in [
      ("a*/b?", "a/bc"),
      ("**/**", "a"),
      ("文档/?.md", "文档/中.md"),
    ] {
    let (pattern, path) = pair
    assert_true(PathGlob::compile(pattern).unwrap().matches(path))
  }
  let glob = PathGlob::compile("**").unwrap()
  for path in ["", "/a", "a/", "a//b", "a/../b", "./a", "a\\b", "a\n"] {
    assert_false(glob.matches(path))
  }
}
