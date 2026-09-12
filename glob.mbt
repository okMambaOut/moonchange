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
  // Keep only the previous pattern row. Updating left-to-right lets '*'
  // consume the current row while literals read the saved diagonal.
  let row = Array::make(value.length() + 1, false)
  row[0] = true
  for p = 0; p < pattern.length(); p = p + 1 {
    let mut diagonal = row[0]
    row[0] = row[0] && pattern[p] == '*'
    for v = 1; v <= value.length(); v = v + 1 {
      let previous = row[v]
      row[v] = match pattern[p] {
        '*' => previous || row[v - 1]
        '?' => diagonal
        literal => diagonal && value[v - 1] == literal
      }
      diagonal = previous
    }
  }
  row[value.length()]
}

///|
pub fn PathGlob::matches(self : PathGlob, path : String) -> Bool {
  if !is_safe_repo_path(path) {
    return false
  }
  let values = path.split("/").map(fn(part) { part.to_owned() }).collect()
  let row = Array::make(values.length() + 1, false)
  row[0] = true
  for pattern in self.segments {
    let mut diagonal = row[0]
    row[0] = row[0] && pattern == "**"
    for v = 1; v <= values.length(); v = v + 1 {
      let previous = row[v]
      row[v] = if pattern == "**" {
        previous || row[v - 1]
      } else {
        diagonal && segment_matches(pattern, values[v - 1])
      }
      diagonal = previous
    }
  }
  row[values.length()]
}
