///|
fn is_ascii_letter(char : Char) -> Bool {
  (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
}

///|
fn is_ascii_digit(char : Char) -> Bool {
  char >= '0' && char <= '9'
}

///|
fn is_identifier(value : String) -> Bool {
  if value.is_empty() || value.length() > 64 {
    return false
  }
  for char in value {
    if !is_ascii_letter(char) &&
      !is_ascii_digit(char) &&
      char != '.' &&
      char != '_' &&
      char != '-' &&
      char != '@' &&
      char != '/' {
      return false
    }
  }
  true
}

///|
fn is_safe_repo_path(path : String) -> Bool {
  if path.is_empty() ||
    path.length() > 1024 ||
    path.has_prefix("/") ||
    path.has_suffix("/") ||
    path.contains("\\") {
    return false
  }
  for part in path.split("/") {
    if part.is_empty() || part == "." || part == ".." {
      return false
    }
    for char in part {
      if char.to_int() < 32 {
        return false
      }
    }
  }
  true
}
