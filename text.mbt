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
fn is_simple_name(value : String) -> Bool {
  if value.is_empty() || value.length() > 64 {
    return false
  }
  for char in value {
    if !is_ascii_letter(char) &&
      !is_ascii_digit(char) &&
      char != '.' &&
      char != '_' &&
      char != '-' {
      return false
    }
  }
  true
}

///|
fn is_principal(value : String) -> Bool {
  if value.length() < 2 || value.length() > 128 || !value.has_prefix("@") {
    return false
  }
  for char in value[1:] {
    if !is_ascii_letter(char) &&
      !is_ascii_digit(char) &&
      char != '.' &&
      char != '_' &&
      char != '-' &&
      char != '/' {
      return false
    }
  }
  true
}

///|
fn contains_string(values : Array[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if !contains_string(values, value) {
    values.push(value)
  }
}

///|
fn normalize_names(
  values : Array[String],
  location : String,
) -> Result[Array[String], Diagnostic] {
  let result : Array[String] = []
  for index, value in values {
    if !is_simple_name(value) {
      return Err(
        Diagnostic::new(
          "policy.name.invalid",
          location + "[" + index.to_string() + "]",
          "policy name is invalid",
          "letters, digits, dot, underscore, or hyphen",
          value,
        ),
      )
    }
    push_unique_string(result, value)
  }
  result.sort_by(fn(left, right) { left.lexical_compare(right) })
  Ok(result)
}

///|
fn split_owned_lines(source : String) -> Array[String] {
  source
  .split("\n")
  .map(fn(line) {
    let owned = line.to_owned()
    if owned.has_suffix("\r") {
      owned[:owned.length() - 1].to_owned()
    } else {
      owned
    }
  })
  .collect()
}

///|
fn split_fields(line : String) -> Array[String] {
  line
  .split(" ")
  .filter(fn(field) { !field.is_empty() })
  .map(fn(field) { field.to_owned() })
  .collect()
}

///|
fn split_csv(value : String) -> Array[String] {
  if value == "-" || value.is_empty() {
    []
  } else {
    value.split(",").map(fn(item) { item.to_owned() }).collect()
  }
}

///|
fn parse_decimal(
  value : String,
  location : String,
  maximum : Int,
) -> Result[Int, Diagnostic] {
  if value.is_empty() {
    return Err(
      Diagnostic::new(
        "syntax.integer", location, "integer is empty", "decimal integer", value,
      ),
    )
  }
  let mut result = 0
  for char in value {
    if !is_ascii_digit(char) {
      return Err(
        Diagnostic::new(
          "syntax.integer", location, "value is not a decimal integer", "decimal integer",
          value,
        ),
      )
    }
    result = result * 10 + char.to_int() - '0'.to_int()
    if result > maximum {
      return Err(
        Diagnostic::new(
          "syntax.integer.limit",
          location,
          "integer exceeds the safety limit",
          "at most " + maximum.to_string(),
          value,
        ),
      )
    }
  }
  Ok(result)
}

///|
fn parse_yes_no(value : String, location : String) -> Result[Bool, Diagnostic] {
  match value {
    "yes" => Ok(true)
    "no" => Ok(false)
    _ =>
      Err(
        Diagnostic::new(
          "syntax.boolean", location, "boolean token is invalid", "yes or no", value,
        ),
      )
  }
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
