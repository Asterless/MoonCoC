///|
fn main {
  let outputs = [
    "def id lam x sort 0 var x", "infer var id", "normalize app var id var y",
  ]
  println(@coc.repl_run_script(outputs))
}
