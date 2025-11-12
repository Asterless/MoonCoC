///|
fn main {
  // Put your main program logic here, run `moon run cmd/main.mbt` to execute.

  // Example1: Running a REPL command using MoonCoc
  let outputs1 = @coc.repl_run_script(["help"])
  println("Outputs: " + outputs1.join(", "))

  // Eample2:
  let outputs2 = @coc.repl_run_script([
    "def id lam x sort 0 var x", "normalize app var id var y",
  ])
  println("Outputs: " + outputs2.join(", "))
}
