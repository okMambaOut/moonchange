///|
test "command help and demo are runnable" {
  let help = execute([])
  assert_eq(help.exit_code(), 0)
  assert_true(help.output().contains("audit-diff"))
  let demo = execute(["demo"])
  assert_eq(demo.exit_code(), 0)
  assert_true(demo.output().contains("STATUS passed"))
}

///|
test "command rejects unknown command and malformed demo" {
  assert_eq(execute(["unknown"]).exit_code(), 2)
  assert_true(execute(["unknown"]).output().contains("cli.command.unknown"))
  assert_eq(execute(["demo", "extra"]).exit_code(), 2)
  assert_true(
    execute(["audit", "--policy"]).output().contains("cli.option.value"),
  )
}
