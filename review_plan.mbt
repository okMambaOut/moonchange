///|
pub struct ReviewPlan {
  required_owners : Array[String]
  approved_owners : Array[String]
  unapproved_owners : Array[String]
  required_checks : Array[String]
  passed_checks : Array[String]
  unresolved_checks : Array[String]
  required_labels : Array[String]
  present_labels : Array[String]
  missing_labels : Array[String]
  touched_rules : Array[String]
  maximum_path_approvals : Int
  release_note_required : Bool
  release_note_present : Bool
} derive(Eq, @debug.Debug)

///|
pub fn ReviewPlan::required_owners(self : ReviewPlan) -> Array[String] {
  self.required_owners.copy()
}

///|
pub fn ReviewPlan::approved_owners(self : ReviewPlan) -> Array[String] {
  self.approved_owners.copy()
}

///|
pub fn ReviewPlan::unapproved_owners(self : ReviewPlan) -> Array[String] {
  self.unapproved_owners.copy()
}

///|
pub fn ReviewPlan::required_checks(self : ReviewPlan) -> Array[String] {
  self.required_checks.copy()
}

///|
pub fn ReviewPlan::passed_checks(self : ReviewPlan) -> Array[String] {
  self.passed_checks.copy()
}

///|
pub fn ReviewPlan::unresolved_checks(self : ReviewPlan) -> Array[String] {
  self.unresolved_checks.copy()
}

///|
pub fn ReviewPlan::required_labels(self : ReviewPlan) -> Array[String] {
  self.required_labels.copy()
}

///|
pub fn ReviewPlan::present_labels(self : ReviewPlan) -> Array[String] {
  self.present_labels.copy()
}

///|
pub fn ReviewPlan::missing_labels(self : ReviewPlan) -> Array[String] {
  self.missing_labels.copy()
}

///|
pub fn ReviewPlan::touched_rules(self : ReviewPlan) -> Array[String] {
  self.touched_rules.copy()
}

///|
pub fn ReviewPlan::maximum_path_approvals(self : ReviewPlan) -> Int {
  self.maximum_path_approvals
}

///|
pub fn ReviewPlan::requires_release_note(self : ReviewPlan) -> Bool {
  self.release_note_required
}

///|
pub fn ReviewPlan::has_release_note(self : ReviewPlan) -> Bool {
  self.release_note_present
}

///|
fn check_is_passed(evidence : Evidence, name : String) -> Bool {
  for check in evidence.checks {
    if check.name == name && check.state == CheckState::Passed {
      return true
    }
  }
  false
}

///|
fn sorted_strings(values : Array[String]) -> Array[String] {
  values.sort_by(fn(left, right) { left.lexical_compare(right) })
  values
}

///|
fn build_review_plan(
  decisions : Array[PathDecision],
  evidence : Evidence,
) -> ReviewPlan {
  let required_owners : Array[String] = []
  let required_checks : Array[String] = []
  let required_labels : Array[String] = []
  let touched_rules : Array[String] = []
  let mut maximum_path_approvals = 0
  let mut release_note_required = false
  for decision in decisions {
    for owner in decision.owners {
      push_unique_string(required_owners, owner)
    }
    for check in decision.checks {
      push_unique_string(required_checks, check)
    }
    for label in decision.labels {
      push_unique_string(required_labels, label)
    }
    for rule in decision.matched_rules {
      push_unique_string(touched_rules, rule)
    }
    if decision.approvals > maximum_path_approvals {
      maximum_path_approvals = decision.approvals
    }
    release_note_required = release_note_required || decision.release_note
  }
  let approved_owners : Array[String] = []
  let unapproved_owners : Array[String] = []
  for owner in required_owners {
    if contains_string(evidence.approvals, owner) {
      approved_owners.push(owner)
    } else {
      unapproved_owners.push(owner)
    }
  }
  let passed_checks : Array[String] = []
  let unresolved_checks : Array[String] = []
  for check in required_checks {
    if check_is_passed(evidence, check) {
      passed_checks.push(check)
    } else {
      unresolved_checks.push(check)
    }
  }
  let present_labels : Array[String] = []
  let missing_labels : Array[String] = []
  for label in required_labels {
    if contains_string(evidence.labels, label) {
      present_labels.push(label)
    } else {
      missing_labels.push(label)
    }
  }
  {
    required_owners: sorted_strings(required_owners),
    approved_owners: sorted_strings(approved_owners),
    unapproved_owners: sorted_strings(unapproved_owners),
    required_checks: sorted_strings(required_checks),
    passed_checks: sorted_strings(passed_checks),
    unresolved_checks: sorted_strings(unresolved_checks),
    required_labels: sorted_strings(required_labels),
    present_labels: sorted_strings(present_labels),
    missing_labels: sorted_strings(missing_labels),
    touched_rules: sorted_strings(touched_rules),
    maximum_path_approvals,
    release_note_required,
    release_note_present: evidence.release_note,
  }
}

///|
pub fn ReviewPlan::to_text(self : ReviewPlan) -> String {
  let release_note_required = if self.release_note_required {
    "yes"
  } else {
    "no"
  }
  let release_note_present = if self.release_note_present {
    "yes"
  } else {
    "no"
  }
  "REQUIRED_OWNERS " +
  format_optional_csv(self.required_owners) +
  "\nAPPROVED_OWNERS " +
  format_optional_csv(self.approved_owners) +
  "\nUNAPPROVED_OWNERS " +
  format_optional_csv(self.unapproved_owners) +
  "\nREQUIRED_CHECKS " +
  format_optional_csv(self.required_checks) +
  "\nPASSED_CHECKS " +
  format_optional_csv(self.passed_checks) +
  "\nUNRESOLVED_CHECKS " +
  format_optional_csv(self.unresolved_checks) +
  "\nREQUIRED_LABELS " +
  format_optional_csv(self.required_labels) +
  "\nPRESENT_LABELS " +
  format_optional_csv(self.present_labels) +
  "\nMISSING_LABELS " +
  format_optional_csv(self.missing_labels) +
  "\nTOUCHED_RULES " +
  format_optional_csv(self.touched_rules) +
  "\nMAX_PATH_APPROVALS " +
  self.maximum_path_approvals.to_string() +
  "\nRELEASE_NOTE_REQUIRED " +
  release_note_required +
  "\nRELEASE_NOTE_PRESENT " +
  release_note_present
}
