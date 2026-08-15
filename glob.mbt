///|
pub struct PathGlob {
  source : String
  segments : Array[String]
  specificity : Int
} derive(Eq, @debug.Debug)

///|
fn validate_glob_segment(
  segment : String,
  location : String,
) -> Result[Int, Diagnostic] {
  if segment.is_empty() || segment == "." || segment == ".." {
    return Err(
      Diagnostic::new(
        "glob.segment.invalid", location, "glob contains an empty or dot segment",
        "non-empty path segment", segment,
      ),
    )
  }
  if segment.contains("**") && segment != "**" {
    return Err(
      Diagnostic::new(
        "glob.double_star.position", location, "double-star must occupy an entire path segment",
        "** between slashes", segment,
      ),
    )
  }
  let mut literal = 0
  for char in segment {
    if char == '[' || char == ']' || char == '{' || char == '}' || char == '\\' {
      return Err(
        Diagnostic::new(
          "glob.character.unsupported",
          location,
          "glob uses unsupported syntax",
          "literal characters, *, ?, and whole-segment **",
          char.to_string(),
        ),
      )
    }
    if char != '*' && char != '?' {
      literal = literal + 1
    }
  }
  Ok(literal)
}

///|
pub fn PathGlob::compile(source : String) -> Result[PathGlob, Diagnostic] {
  if source.is_empty() ||
    source.length() > 1024 ||
    source.has_prefix("/") ||
    source.has_suffix("/") {
    return Err(
      Diagnostic::new(
        "glob.path.invalid", "glob", "glob is empty, absolute, too long, or slash-terminated",
        "repository-relative glob up to 1024 characters", source,
      ),
    )
  }
  let segments : Array[String] = []
  let mut specificity = 0
  for index, view in source.split("/") {
    let segment = view.to_owned()
    let score = match
      validate_glob_segment(segment, "glob.segments[" + index.to_string() + "]") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    segments.push(segment)
    specificity = specificity + score
    if segment != "**" {
      specificity = specificity + 2
    }
  }
  Ok({ source, segments, specificity })
}

///|
pub fn PathGlob::source(self : PathGlob) -> String {
  self.source
}

///|
pub fn PathGlob::specificity(self : PathGlob) -> Int {
  self.specificity
}

///|
fn segment_matches(pattern : String, value : String) -> Bool {
  let width = value.length() + 1
  let table = Array::make((pattern.length() + 1) * width, false)
  table[0] = true
  for p = 0; p < pattern.length(); p = p + 1 {
    for v = 0; v <= value.length(); v = v + 1 {
      if !table[p * width + v] {
        continue
      }
      match pattern[p] {
        '*' => {
          table[(p + 1) * width + v] = true
          if v < value.length() {
            table[p * width + v + 1] = true
          }
        }
        '?' => if v < value.length() { table[(p + 1) * width + v + 1] = true }
        literal =>
          if v < value.length() && value[v] == literal {
            table[(p + 1) * width + v + 1] = true
          }
      }
    }
  }
  table[pattern.length() * width + value.length()]
}

///|
pub fn PathGlob::matches(self : PathGlob, path : String) -> Bool {
  if !is_safe_repo_path(path) {
    return false
  }
  let values = path.split("/").map(fn(part) { part.to_owned() }).collect()
  let width = values.length() + 1
  let table = Array::make((self.segments.length() + 1) * width, false)
  table[0] = true
  for pattern_index = 0
      pattern_index < self.segments.length()
      pattern_index = pattern_index + 1 {
    for value_index = 0
        value_index <= values.length()
        value_index = value_index + 1 {
      if !table[pattern_index * width + value_index] {
        continue
      }
      let pattern = self.segments[pattern_index]
      if pattern == "**" {
        table[(pattern_index + 1) * width + value_index] = true
        if value_index < values.length() {
          table[pattern_index * width + value_index + 1] = true
        }
      } else if value_index < values.length() &&
        segment_matches(pattern, values[value_index]) {
        table[(pattern_index + 1) * width + value_index + 1] = true
      }
    }
  }
  table[self.segments.length() * width + values.length()]
}
