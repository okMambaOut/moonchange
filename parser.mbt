///|
fn syntax_error(
  code : String,
  line : Int,
  message : String,
  expected : String,
  actual : String,
) -> Diagnostic {
  Diagnostic::new(
    code,
    "lines[" + line.to_string() + "]",
    message,
    expected,
    actual,
  )
}

///|
fn parse_key_values(
  fields : Array[String],
  start : Int,
  line : Int,
) -> Result[Array[(String, String)], Diagnostic] {
  let result : Array[(String, String)] = []
  for index = start; index < fields.length(); index = index + 1 {
    let field = fields[index]
    let split = match field[:].find("=") {
      Some(value) => value
      None =>
        return Err(
          syntax_error(
            "policy.option.syntax", line, "rule option is not key=value", "key=value",
            field,
          ),
        )
    }
    if split == 0 || split == field.length() - 1 {
      return Err(
        syntax_error(
          "policy.option.syntax", line, "rule option has an empty key or value",
          "key=value", field,
        ),
      )
    }
    let key = field[:split].to_owned()
    let value = field[split + 1:].to_owned()
    for pair in result {
      let (existing, _) = pair
      if existing == key {
        return Err(
          syntax_error(
            "policy.option.duplicate", line, "rule option appears more than once",
            "unique option key", key,
          ),
        )
      }
    }
    result.push((key, value))
  }
  Ok(result)
}

///|
fn option_value(options : Array[(String, String)], key : String) -> String? {
  for pair in options {
    let (name, value) = pair
    if name == key {
      return Some(value)
    }
  }
  None
}

///|
fn ensure_rule_options(
  options : Array[(String, String)],
  line : Int,
) -> Result[Unit, Diagnostic] {
  let supported = [
    "approvals", "checks", "labels", "forbid", "max_lines", "release_note", "binary",
  ]
  for pair in options {
    let (key, _) = pair
    if !contains_string(supported, key) {
      return Err(
        syntax_error(
          "policy.option.unknown",
          line,
          "rule option is unknown",
          supported.join(","),
          key,
        ),
      )
    }
  }
  Ok(())
}

///|
fn parse_forbidden(
  value : String,
  line : Int,
) -> Result[Array[ChangeKind], Diagnostic] {
  let result : Array[ChangeKind] = []
  for token in split_csv(value) {
    match ChangeKind::parse(token) {
      Some(kind) => if !contains_kind(result, kind) { result.push(kind) }
      None =>
        return Err(
          syntax_error(
            "policy.kind.invalid", line, "forbidden operation is invalid", "add, modify, delete, rename, or copy",
            token,
          ),
        )
    }
  }
  Ok(result)
}

///|
fn parse_governance_rule(
  fields : Array[String],
  line : Int,
) -> Result[GovernanceRule, Diagnostic] {
  if fields.length() < 3 {
    return Err(
      syntax_error(
        "policy.rule.shape",
        line,
        "rule line has too few fields",
        "RULE name glob [key=value ...]",
        fields.join(" "),
      ),
    )
  }
  let pattern = match PathGlob::compile(fields[2]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let options = match parse_key_values(fields, 3, line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match ensure_rule_options(options, line) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let approvals = match option_value(options, "approvals") {
    Some(value) =>
      match
        parse_decimal(value, "lines[" + line.to_string() + "].approvals", 20) {
        Ok(number) => number
        Err(error) => return Err(error)
      }
    None => 0
  }
  let checks = match option_value(options, "checks") {
    Some(value) => split_csv(value)
    None => []
  }
  let labels = match option_value(options, "labels") {
    Some(value) => split_csv(value)
    None => []
  }
  let forbidden = match option_value(options, "forbid") {
    Some(value) =>
      match parse_forbidden(value, line) {
        Ok(kinds) => kinds
        Err(error) => return Err(error)
      }
    None => []
  }
  let max_lines = match option_value(options, "max_lines") {
    Some("-") => None
    Some(value) =>
      match
        parse_decimal(
          value,
          "lines[" + line.to_string() + "].max_lines",
          10000000,
        ) {
        Ok(number) => Some(number)
        Err(error) => return Err(error)
      }
    None => None
  }
  let release_note = match option_value(options, "release_note") {
    Some(value) =>
      match
        parse_yes_no(value, "lines[" + line.to_string() + "].release_note") {
        Ok(flag) => flag
        Err(error) => return Err(error)
      }
    None => false
  }
  let allow_binary = match option_value(options, "binary") {
    Some("allow") => true
    Some("deny") => false
    Some(value) =>
      return Err(
        syntax_error(
          "policy.binary.invalid", line, "binary option is invalid", "allow or deny",
          value,
        ),
      )
    None => true
  }
  GovernanceRule::new(
    fields[1],
    pattern,
    approvals~,
    checks~,
    labels~,
    forbidden~,
    max_lines~,
    release_note~,
    allow_binary~,
  )
}

///|
pub fn parse_policy(source : String) -> Result[Policy, Diagnostic] {
  if source.is_empty() || source.length() > 4194304 {
    return Err(
      Diagnostic::new(
        "policy.input.limit",
        "policy",
        "policy is empty or exceeds the input limit",
        "1 through 4194304 characters",
        source.length().to_string(),
      ),
    )
  }
  let lines = split_owned_lines(source)
  if lines.is_empty() || lines[0] != "MOONCHANGE_POLICY 1" {
    return Err(
      syntax_error(
        "policy.header",
        0,
        "policy header is missing or unsupported",
        "MOONCHANGE_POLICY 1",
        if lines.is_empty() {
          "end of input"
        } else {
          lines[0]
        },
      ),
    )
  }
  let owners : Array[OwnerRule] = []
  let rules : Array[GovernanceRule] = []
  let mut default_approvals = 1
  let mut max_total_lines : Int? = None
  let mut require_owned = true
  let mut saw_default = false
  for index = 1; index < lines.length(); index = index + 1 {
    let line = lines[index]
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let fields = split_fields(line)
    match fields[0] {
      "DEFAULT" => {
        if saw_default {
          return Err(
            syntax_error(
              "policy.default.duplicate", index, "DEFAULT appears more than once",
              "one DEFAULT line", line,
            ),
          )
        }
        saw_default = true
        let options = match parse_key_values(fields, 1, index) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        for pair in options {
          let (key, _) = pair
          if key != "approvals" && key != "max_total" && key != "require_owned" {
            return Err(
              syntax_error(
                "policy.option.unknown", index, "default option is unknown", "approvals,max_total,require_owned",
                key,
              ),
            )
          }
        }
        match option_value(options, "approvals") {
          Some(value) =>
            match
              parse_decimal(
                value,
                "lines[" + index.to_string() + "].approvals",
                20,
              ) {
              Ok(number) => default_approvals = number
              Err(error) => return Err(error)
            }
          None => ()
        }
        match option_value(options, "max_total") {
          Some("-") => max_total_lines = None
          Some(value) =>
            match
              parse_decimal(
                value,
                "lines[" + index.to_string() + "].max_total",
                100000000,
              ) {
              Ok(number) => max_total_lines = Some(number)
              Err(error) => return Err(error)
            }
          None => ()
        }
        match option_value(options, "require_owned") {
          Some(value) =>
            match
              parse_yes_no(
                value,
                "lines[" + index.to_string() + "].require_owned",
              ) {
              Ok(flag) => require_owned = flag
              Err(error) => return Err(error)
            }
          None => ()
        }
      }
      "OWNER" => {
        if fields.length() != 3 {
          return Err(
            syntax_error(
              "policy.owner.shape", index, "owner line has the wrong shape", "OWNER glob @owner[,owner]",
              line,
            ),
          )
        }
        let pattern = match PathGlob::compile(fields[1]) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let rule = match OwnerRule::new(pattern, split_csv(fields[2])) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        owners.push(rule)
      }
      "RULE" =>
        match parse_governance_rule(fields, index) {
          Ok(rule) => rules.push(rule)
          Err(error) => return Err(error)
        }
      command =>
        return Err(
          syntax_error(
            "policy.command.unknown", index, "policy command is unknown", "DEFAULT, OWNER, or RULE",
            command,
          ),
        )
    }
  }
  Policy::new(
    default_approvals~,
    max_total_lines~,
    require_owned~,
    owner_rules=owners,
    rules~,
  )
}

///|
fn format_optional_csv(values : Array[String]) -> String {
  if values.is_empty() {
    "-"
  } else {
    values.join(",")
  }
}

///|
pub fn Policy::to_text(self : Policy) -> String {
  let output = StringBuilder()
  let max_total = match self.max_total_lines {
    Some(value) => value.to_string()
    None => "-"
  }
  let require_owned = if self.require_owned { "yes" } else { "no" }
  output.write_string("MOONCHANGE_POLICY 1\n")
  output.write_string(
    "DEFAULT approvals=" +
    self.default_approvals.to_string() +
    " max_total=" +
    max_total +
    " require_owned=" +
    require_owned,
  )
  for owner in self.owner_rules {
    output.write_string(
      "\nOWNER " + owner.pattern.source() + " " + owner.owners.join(","),
    )
  }
  for rule in self.rules {
    let forbidden = rule.forbidden.map(fn(kind) { kind.to_text() })
    let max_lines = match rule.max_lines {
      Some(value) => value.to_string()
      None => "-"
    }
    let release_note = if rule.release_note { "yes" } else { "no" }
    let binary = if rule.allow_binary { "allow" } else { "deny" }
    output.write_string(
      "\nRULE " +
      rule.name +
      " " +
      rule.pattern.source() +
      " approvals=" +
      rule.approvals.to_string() +
      " checks=" +
      format_optional_csv(rule.checks) +
      " labels=" +
      format_optional_csv(rule.labels) +
      " forbid=" +
      format_optional_csv(forbidden) +
      " max_lines=" +
      max_lines +
      " release_note=" +
      release_note +
      " binary=" +
      binary,
    )
  }
  output.to_string()
}

///|
fn parse_change_line(
  fields : Array[String],
  line : Int,
) -> Result[Change, Diagnostic] {
  if fields.length() < 6 {
    return Err(
      syntax_error(
        "manifest.change.shape",
        line,
        "change line has too few fields",
        "CHANGE kind path fields additions deletions text|binary",
        fields.join(" "),
      ),
    )
  }
  let kind = match ChangeKind::parse(fields[1]) {
    Some(value) => value
    None =>
      return Err(
        syntax_error(
          "manifest.kind.invalid",
          line,
          "change operation is invalid",
          "add, modify, delete, rename, or copy",
          fields[1],
        ),
      )
  }
  let path_fields = if kind == Rename || kind == Copy { 2 } else { 1 }
  let expected_length = 2 + path_fields + 3
  if fields.length() != expected_length {
    return Err(
      syntax_error(
        "manifest.change.shape",
        line,
        "change line has the wrong number of fields",
        if path_fields == 2 {
          "CHANGE kind old new additions deletions text|binary"
        } else {
          "CHANGE kind path additions deletions text|binary"
        },
        fields.join(" "),
      ),
    )
  }
  let additions_index = 2 + path_fields
  let additions = match
    parse_decimal(
      fields[additions_index],
      "lines[" + line.to_string() + "].additions",
      10000000,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let deletions = match
    parse_decimal(
      fields[additions_index + 1],
      "lines[" + line.to_string() + "].deletions",
      10000000,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let binary = match fields[additions_index + 2] {
    "text" => false
    "binary" => true
    value =>
      return Err(
        syntax_error(
          "manifest.content.invalid", line, "content kind is invalid", "text or binary",
          value,
        ),
      )
  }
  let (old_path, new_path) = match kind {
    Add => (None, Some(fields[2]))
    Delete => (Some(fields[2]), None)
    Modify => (Some(fields[2]), Some(fields[2]))
    Rename | Copy => (Some(fields[2]), Some(fields[3]))
  }
  Change::new(kind, old_path, new_path, additions, deletions, binary~)
}

///|
pub fn parse_manifest(source : String) -> Result[ChangeSet, Diagnostic] {
  if source.is_empty() || source.length() > 4194304 {
    return Err(
      Diagnostic::new(
        "manifest.input.limit",
        "manifest",
        "manifest is empty or exceeds the input limit",
        "1 through 4194304 characters",
        source.length().to_string(),
      ),
    )
  }
  let lines = split_owned_lines(source)
  if lines.is_empty() || lines[0] != "MOONCHANGE 1" {
    return Err(
      syntax_error(
        "manifest.header",
        0,
        "manifest header is missing or unsupported",
        "MOONCHANGE 1",
        if lines.is_empty() {
          "end of input"
        } else {
          lines[0]
        },
      ),
    )
  }
  let mut id : String? = None
  let mut actor : String? = None
  let approvals : Array[String] = []
  let checks : Array[CheckResult] = []
  let labels : Array[String] = []
  let changes : Array[Change] = []
  let mut release_note = false
  let mut saw_release_note = false
  for index = 1; index < lines.length(); index = index + 1 {
    let line = lines[index]
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let fields = split_fields(line)
    match fields[0] {
      "ID" => {
        if fields.length() != 2 || id is Some(_) {
          return Err(
            syntax_error(
              "manifest.id.shape", index, "ID is duplicate or malformed", "one ID value",
              line,
            ),
          )
        }
        id = Some(fields[1])
      }
      "ACTOR" => {
        if fields.length() != 2 || actor is Some(_) || !is_principal(fields[1]) {
          return Err(
            syntax_error(
              "manifest.actor.shape", index, "ACTOR is duplicate, malformed, or invalid",
              "one @principal", line,
            ),
          )
        }
        actor = Some(fields[1])
      }
      "APPROVAL" => {
        if fields.length() != 2 || !is_principal(fields[1]) {
          return Err(
            syntax_error(
              "manifest.approval.shape", index, "APPROVAL is malformed", "APPROVAL @principal",
              line,
            ),
          )
        }
        push_unique_string(approvals, fields[1])
      }
      "CHECK" => {
        if fields.length() != 3 || !is_simple_name(fields[1]) {
          return Err(
            syntax_error(
              "manifest.check.shape", index, "CHECK is malformed", "CHECK name passed|failed|pending",
              line,
            ),
          )
        }
        let state = match CheckState::parse(fields[2]) {
          Some(value) => value
          None =>
            return Err(
              syntax_error(
                "manifest.check.state",
                index,
                "check state is invalid",
                "passed, failed, or pending",
                fields[2],
              ),
            )
        }
        for existing in checks {
          if existing.name == fields[1] {
            return Err(
              syntax_error(
                "manifest.check.duplicate",
                index,
                "check name appears more than once",
                "unique check name",
                fields[1],
              ),
            )
          }
        }
        checks.push(CheckResult::new(fields[1], state))
      }
      "LABEL" => {
        if fields.length() != 2 || !is_simple_name(fields[1]) {
          return Err(
            syntax_error(
              "manifest.label.shape", index, "LABEL is malformed", "LABEL name",
              line,
            ),
          )
        }
        push_unique_string(labels, fields[1])
      }
      "RELEASE_NOTE" => {
        if fields.length() != 2 || saw_release_note {
          return Err(
            syntax_error(
              "manifest.release_note.shape", index, "RELEASE_NOTE is duplicate or malformed",
              "one RELEASE_NOTE yes|no", line,
            ),
          )
        }
        saw_release_note = true
        release_note = match
          parse_yes_no(
            fields[1],
            "lines[" + index.to_string() + "].release_note",
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      }
      "CHANGE" =>
        match parse_change_line(fields, index) {
          Ok(change) => changes.push(change)
          Err(error) => return Err(error)
        }
      command =>
        return Err(
          syntax_error(
            "manifest.command.unknown", index, "manifest command is unknown", "ID, ACTOR, APPROVAL, CHECK, LABEL, RELEASE_NOTE, or CHANGE",
            command,
          ),
        )
    }
  }
  if id is None {
    return Err(
      Diagnostic::new(
        "manifest.id.missing", "manifest", "manifest has no ID", "ID value", "missing",
      ),
    )
  }
  if actor is None {
    return Err(
      Diagnostic::new(
        "manifest.actor.missing", "manifest", "manifest has no actor", "ACTOR @principal",
        "missing",
      ),
    )
  }
  approvals.sort_by(fn(left, right) { left.lexical_compare(right) })
  labels.sort_by(fn(left, right) { left.lexical_compare(right) })
  let evidence = Evidence::new(
    actor.unwrap(),
    approvals,
    checks,
    labels,
    release_note~,
  )
  ChangeSet::new(id.unwrap(), changes, evidence)
}

///|
pub fn ChangeSet::to_text(self : ChangeSet) -> String {
  let output = StringBuilder()
  let release_note = if self.evidence.release_note { "yes" } else { "no" }
  output.write_string(
    "MOONCHANGE 1\nID " + self.id + "\nACTOR " + self.evidence.actor,
  )
  for approval in self.evidence.approvals {
    output.write_string("\nAPPROVAL " + approval)
  }
  for check in self.evidence.checks {
    output.write_string("\nCHECK " + check.name + " " + check.state.to_text())
  }
  for label in self.evidence.labels {
    output.write_string("\nLABEL " + label)
  }
  output.write_string("\nRELEASE_NOTE " + release_note)
  for change in self.changes {
    output.write_string("\nCHANGE " + change.kind.to_text() + " ")
    match change.kind {
      Add => output.write_string(change.new_path.unwrap())
      Delete => output.write_string(change.old_path.unwrap())
      Modify => output.write_string(change.new_path.unwrap())
      Rename | Copy =>
        output.write_string(
          change.old_path.unwrap() + " " + change.new_path.unwrap(),
        )
    }
    let content_kind = if change.binary { " binary" } else { " text" }
    output.write_string(
      " " +
      change.additions.to_string() +
      " " +
      change.deletions.to_string() +
      content_kind,
    )
  }
  output.to_string()
}
