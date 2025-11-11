///|
/// Basic tests / examples for CoC scaffold
pub fn test_core_demo() -> String {
  // placeholder test: returns known string for test harness
  "CoC REPL demo scaffold (core functions in src/coc_core.mbt)"
}

///|
test "beta-reduction" {
  // (\x. x) y  => Var(y)
  let lam = mk_lam("x", mk_sort(0), mk_var("x"))
  let app = mk_app(lam, mk_var("y"))
  inspect(pp(whnf(app)), content="Var(y)")
}

///|
test "subst-shadowing" {
  // (\x. \x. x) a  => \x. x
  let inner = mk_lam("x", mk_sort(0), mk_var("x"))
  let outer = mk_lam("x", mk_sort(0), inner)
  let app = mk_app(outer, mk_var("a"))
  inspect(pp(whnf(app)), content="Lam(x,Sort(0),Var(x))")
}

///|
test "normalize-nested" {
  // ((\x. x) (\z. z)) k  => Var(k)
  let id = mk_lam("x", mk_sort(0), mk_var("x"))
  let lam_z = mk_lam("z", mk_sort(0), mk_var("z"))
  let inner = normalize(mk_app(id, lam_z))
  let app = mk_app(inner, mk_var("k"))
  inspect(pp(normalize(app)), content="Var(k)")
}

///|
test "type-infer-pi" {
  let pi = mk_pi("x", mk_sort(0), mk_var("x"))
  inspect(pp(type_infer(empty_ctx(), pi)), content="Sort(1)")
}

///|
test "type-infer-pi-universe-levels" {
  // Test that Pi(x:A, B) has universe level max(level(A), level(B) + 1)
  // Case 1: Pi(x:Sort(0), Sort(1)) should have type Sort(max(0, 1+1)) = Sort(2)
  let pi1 = mk_pi("x", mk_sort(0), mk_sort(1))
  inspect(pp(type_infer(empty_ctx(), pi1)), content="Sort(2)")
  
  // Case 2: Pi(x:Sort(2), Sort(0)) should have type Sort(max(2, 0+1)) = Sort(2)
  let pi2 = mk_pi("x", mk_sort(2), mk_sort(0))
  inspect(pp(type_infer(empty_ctx(), pi2)), content="Sort(2)")
  
  // Case 3: Pi(x:Sort(1), Sort(1)) should have type Sort(max(1, 1+1)) = Sort(2)
  let pi3 = mk_pi("x", mk_sort(1), mk_sort(1))
  inspect(pp(type_infer(empty_ctx(), pi3)), content="Sort(2)")
  
  // Case 4: Pi(x:Sort(0), Sort(0)) should have type Sort(max(0, 0+1)) = Sort(1)
  let pi4 = mk_pi("x", mk_sort(0), mk_sort(0))
  inspect(pp(type_infer(empty_ctx(), pi4)), content="Sort(1)")
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
