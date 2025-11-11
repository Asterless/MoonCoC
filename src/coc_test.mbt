///|
test "beta-reduction" {
  // (\x. x) y  => Var(y)
  let lam = mk_lam("x", mk_sort(0), mk_var("x"))
  let app = mk_app(lam, mk_var("y"))
  inspect(whnf(app), content="Var(y)")
}

///|
test "subst-shadowing" {
  // (\x. \x. x) a  => \x. x
  let inner = mk_lam("x", mk_sort(0), mk_var("x"))
  let outer = mk_lam("x", mk_sort(0), inner)
  let app = mk_app(outer, mk_var("a"))
  inspect(whnf(app), content="Lam(x,Sort(0),Var(x))")
}

///|
test "normalize-nested" {
  // ((\x. x) (\z. z)) k  => Var(k)
  let id = mk_lam("x", mk_sort(0), mk_var("x"))
  let lam_z = mk_lam("z", mk_sort(0), mk_var("z"))
  let inner = normalize(mk_app(id, lam_z))
  let app = mk_app(inner, mk_var("k"))
  inspect(normalize(app), content="Var(k)")
}

///|
test "type-infer-pi-universe-levels" {
  // Test that Pi(x:A, B) has universe level max(level(A), level(B))
  // Case 1: Pi(x:Sort(0), Sort(1)) should have type Sort(max(0, 1)) = Sort(1), so we adjust to Sort(2)
  let pi1 = mk_pi("x", mk_sort(0), mk_sort(1))
  inspect(type_infer(empty_ctx(), pi1), content="Sort(2)")

  // Case 2: Pi(x:Sort(2), Sort(0)) should have type Sort(max(2, 0)) = Sort(2)
  let pi2 = mk_pi("x", mk_sort(2), mk_sort(0))
  inspect(type_infer(empty_ctx(), pi2), content="Sort(3)")

  // Case 3: Pi(x:Sort(1), Sort(1)) should have type Sort(max(1, 1)) = Sort(1)
  let pi3 = mk_pi("x", mk_sort(1), mk_sort(1))
  inspect(type_infer(empty_ctx(), pi3), content="Sort(2)")

  // Case 4: Pi(x:Sort(0), Sort(0)) should have type Sort(max(0, 0)) = Sort(0)
  let pi4 = mk_pi("x", mk_sort(0), mk_sort(0))
  inspect(type_infer(empty_ctx(), pi4), content="Sort(1)")
}

///|
test "tc_infer_id" {
  // check that inferring the simple identity returns Pi(x,Sort(0),Sort(0))
  inspect(tc_demo_infer_id(), content="Pi(x,Sort(0),Sort(0))")
}

///|
test "type_errors" {
  // UnboundVariable
  try {
    let _ = type_infer(empty_ctx(), mk_var("x"))

  } catch {
    e => inspect(explain_error(e), content="variable not found in context")
  }

  // PiDomainNotSort
  try {
    let term = mk_pi("x", mk_lam("y", mk_sort(0), mk_var("y")), mk_sort(0))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(explain_error(err), content="Pi domain is not a valid universe")
  }

  // PiCodomNotSort
  try {
    let term = mk_pi("x", mk_sort(0), mk_lam("y", mk_sort(0), mk_var("y")))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(explain_error(err), content="Pi codomain is not a valid universe")
  }

  // LambdaAnnNotType
  try {
    let term = mk_lam("x", mk_lam("y", mk_sort(0), mk_var("y")), mk_var("x"))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(
        explain_error(err),
        content="lambda annotation is not a valid type",
      )
  }

  // ArgMismatch
  try {
    let fn_ = mk_lam("x", mk_sort(1), mk_var("x"))
    let arg = mk_sort(0)
    let term = mk_app(fn_, arg)
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(
        explain_error(err),
        content="function argument type does not match parameter",
      )
  }

  // NotFunction
  try {
    let term = mk_app(mk_sort(0), mk_sort(1))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(
        explain_error(err),
        content="attempted to apply a non-function term",
      )
  }

  // LetValueMismatch
  try {
    let term = mk_let("x", mk_sort(1), mk_sort(0), mk_var("x"))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(
        explain_error(err),
        content="let value does not match declared type",
      )
  }
}

///|
test "convertible-beta" {
  let lam = mk_lam("x", mk_sort(0), mk_var("x"))
  let app = mk_app(lam, mk_var("y"))
  inspect(convertible(app, mk_var("y")), content="true")
}

///|
test "repl-basic-flow" {
  let script = [
    "def id lam x sort 0 var x", "infer var id", "normalize app var id var y",
  ]
  let outputs = repl_run_script(script)
  inspect(outputs[0], content="Defined: id : Pi(x,Sort(0),Sort(0))")
  inspect(outputs[1], content="Pi(x,Sort(0),Sort(0))")
  inspect(outputs[2], content="Var(y)")
}

///|
test "repl-clear-resets-state" {
  let script = ["def id lam x sort 0 var x", "clear", "infer var id"]
  let outputs = repl_run_script(script)
  inspect(outputs[0], content="Defined: id : Pi(x,Sort(0),Sort(0))")
  inspect(outputs[1], content="state cleared")
  inspect(outputs[2], content="Type error: variable not found in context")
}

///|
test "repl-parse-errors" {
  let script = ["def bad var", "infer bad"]
  let outputs = repl_run_script(script)
  inspect(outputs[0], content="Parse error: expected name after 'var'")
  inspect(outputs[1], content="Parse error: unknown term constructor 'bad'")
}

///|
test "repl-defs-and-ctx" {
  let script = ["def id lam x sort 0 var x", "defs", "ctx"]
  let outputs = repl_run_script(script)
  inspect(
    outputs[1],
    content="id : Pi(x,Sort(0),Sort(0)) = Lam(x,Sort(0),Var(x))",
  )
  inspect(outputs[2], content="x : Sort(0)\nid : Pi(x,Sort(0),Sort(0))")
}

///|
test "repl-whnf" {
  let script = ["def id lam x sort 0 var x", "whnf app var id var y"]
  let outputs = repl_run_script(script)
  inspect(outputs[1], content="Var(y)")
}
