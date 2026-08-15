///|
pub struct CommandResult {
  exit_code : Int
  output : String
} derive(Eq, @debug.Debug)

///|
pub fn CommandResult::exit_code(self : CommandResult) -> Int {
  self.exit_code
}

///|
pub fn CommandResult::output(self : CommandResult) -> String {
  self.output
}

///|
fn command_result(exit_code : Int, output : String) -> CommandResult {
  { exit_code, output }
}

///|
fn usage() -> String {
  "MoonChange - repository change-governance gates\n\n" +
  "USAGE:\n" +
  "  moonchange audit --policy FILE --manifest FILE\n" +
  "  moonchange audit-diff --policy FILE --evidence FILE --diff FILE\n" +
  "  moonchange explain --policy FILE --path REPOSITORY_PATH\n" +
  "  moonchange lint --policy FILE\n" +
  "  moonchange demo\n\n" +
  "EXIT CODES:\n" +
  "  0 passed, 1 needs review or has lint warnings, 2 rejected or invalid input"
}

///|
fn cli_option(
  args : Array[String],
  name : String,
) -> Result[String, Diagnostic] {
  let mut found : String? = None
  let mut index = 1
  while index < args.length() {
    if args[index] == name {
      if found is Some(_) {
        return Err(
          Diagnostic::new(
            "cli.option.duplicate", name, "option appears more than once", "one value",
            "duplicate",
          ),
        )
      }
      if index + 1 >= args.length() {
        return Err(
          Diagnostic::new(
            "cli.option.value", name, "option is missing its value", "value after option",
            "missing",
          ),
        )
      }
      found = Some(args[index + 1])
      index = index + 2
    } else {
      index = index + 1
    }
  }
  match found {
    Some(value) => Ok(value)
    None =>
      Err(
        Diagnostic::new(
          "cli.option.required",
          name,
          "required option is missing",
          name + " VALUE",
          "missing",
        ),
      )
  }
}

///|
fn cli_check_options(
  args : Array[String],
  allowed : Array[String],
) -> Result[Unit, Diagnostic] {
  let mut index = 1
  while index < args.length() {
    let name = args[index]
    if !name.has_prefix("--") {
      return Err(
        Diagnostic::new(
          "cli.argument.unexpected",
          "args[" + index.to_string() + "]",
          "unexpected positional argument",
          "named option",
          name,
        ),
      )
    }
    if !contains_string(allowed, name) {
      return Err(
        Diagnostic::new(
          "cli.option.unknown",
          "args[" + index.to_string() + "]",
          "unknown option",
          allowed.join(","),
          name,
        ),
      )
    }
    if index + 1 >= args.length() {
      return Err(
        Diagnostic::new(
          "cli.option.value", name, "option is missing its value", "value after option",
          "missing",
        ),
      )
    }
    index = index + 2
  }
  Ok(())
}

///|
fn read_cli_file(
  path : String,
  option_name : String,
) -> Result[String, Diagnostic] {
  let content = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) =>
      return Err(
        Diagnostic::new(
          "cli.file.read",
          option_name,
          "cannot read UTF-8 input file",
          "readable file",
          path + ": " + message,
        ),
      )
  }
  Ok(content)
}

///|
fn load_policy(args : Array[String]) -> Result[Policy, Diagnostic] {
  let path = match cli_option(args, "--policy") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source = match read_cli_file(path, "--policy") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  parse_policy(source)
}

///|
fn gate_exit(status : GateStatus) -> Int {
  match status {
    GateStatus::Passed => 0
    Review => 1
    Rejected => 2
  }
}

///|
fn audit_command(args : Array[String]) -> Result[CommandResult, Diagnostic] {
  match cli_check_options(args, ["--policy", "--manifest"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let policy = match load_policy(args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manifest_path = match cli_option(args, "--manifest") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source = match read_cli_file(manifest_path, "--manifest") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let changes = match parse_manifest(source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = evaluate(policy, changes)
  Ok(command_result(gate_exit(report.status), report.to_text()))
}

///|
fn audit_diff_command(
  args : Array[String],
) -> Result[CommandResult, Diagnostic] {
  match cli_check_options(args, ["--policy", "--evidence", "--diff"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let policy = match load_policy(args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let evidence_path = match cli_option(args, "--evidence") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let evidence_source = match read_cli_file(evidence_path, "--evidence") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let review = match parse_review_evidence(evidence_source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let diff_path = match cli_option(args, "--diff") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let diff_source = match read_cli_file(diff_path, "--diff") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let changes = match
    change_set_from_unified_diff(review.id, review.evidence, diff_source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = evaluate(policy, changes)
  Ok(command_result(gate_exit(report.status), report.to_text()))
}

///|
fn explain_command(args : Array[String]) -> Result[CommandResult, Diagnostic] {
  match cli_check_options(args, ["--policy", "--path"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let policy = match load_policy(args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let path = match cli_option(args, "--path") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match policy.explain(path) {
    Ok(value) => Ok(command_result(0, value.to_text()))
    Err(error) => Err(error)
  }
}

///|
fn lint_command(args : Array[String]) -> Result[CommandResult, Diagnostic] {
  match cli_check_options(args, ["--policy"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let policy = match load_policy(args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = lint_policy(policy)
  let exit_code = if report.has_errors() {
    2
  } else if report.is_clean() {
    0
  } else {
    1
  }
  Ok(command_result(exit_code, report.to_text()))
}

///|
fn demo_command() -> Result[CommandResult, Diagnostic] {
  let policy = match
    parse_policy(
      "MOONCHANGE_POLICY 1\nDEFAULT approvals=1 max_total=300 require_owned=yes\nOWNER **/* @maintainers\nOWNER src/security/** @security,@maintainers\nRULE source src/** approvals=1 checks=unit labels=code forbid=delete max_lines=200 release_note=no binary=deny\nRULE security src/security/** approvals=2 checks=security labels=security-reviewed forbid=rename max_lines=80 release_note=yes binary=deny",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let changes = match
    parse_manifest(
      "MOONCHANGE 1\nID DEMO-1\nACTOR @alice\nAPPROVAL @maintainers\nAPPROVAL @security\nCHECK unit passed\nCHECK security passed\nLABEL code\nLABEL security-reviewed\nRELEASE_NOTE yes\nCHANGE modify src/security/auth.mbt 20 4 text",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = evaluate(policy, changes)
  Ok(command_result(gate_exit(report.status), report.to_text()))
}

///|
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    return command_result(0, usage())
  }
  let result = match args[0] {
    "audit" => audit_command(args)
    "audit-diff" => audit_diff_command(args)
    "explain" => explain_command(args)
    "lint" => lint_command(args)
    "demo" =>
      if args.length() == 1 {
        demo_command()
      } else {
        Err(
          Diagnostic::new(
            "cli.argument.unexpected",
            "args[1]",
            "demo accepts no arguments",
            "no arguments",
            args[1],
          ),
        )
      }
    command =>
      Err(
        Diagnostic::new(
          "cli.command.unknown", "args[0]", "unknown command", "audit, audit-diff, explain, lint, demo, or help",
          command,
        ),
      )
  }
  match result {
    Ok(value) => value
    Err(error) => command_result(2, error.to_text())
  }
}
