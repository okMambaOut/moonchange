///|
/// A stable, machine-readable policy, manifest, or evaluation failure.
pub struct Diagnostic {
  code : String
  location : String
  message : String
  expected : String
  actual : String
} derive(Eq, @debug.Debug)

///|
pub fn Diagnostic::new(
  code : String,
  location : String,
  message : String,
  expected : String,
  actual : String,
) -> Diagnostic {
  { code, location, message, expected, actual, }
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> String {
  self.code
}

///|
pub fn Diagnostic::location(self : Diagnostic) -> String {
  self.location
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::expected(self : Diagnostic) -> String {
  self.expected
}

///|
pub fn Diagnostic::actual(self : Diagnostic) -> String {
  self.actual
}

///|
pub fn Diagnostic::to_text(self : Diagnostic) -> String {
  self.code +
  " at " +
  self.location +
  ": " +
  self.message +
  " (expected " +
  self.expected +
  ", got " +
  self.actual +
  ")"
}
