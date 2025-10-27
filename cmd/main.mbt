///|
///
fn main {
  println("MoonCoc REPL (type :quit or :q to exit)")
  println("Type \"coc help\" to list available commands.")
  let rl : @rl.T = @rl.new()
  let state = @coc.repl_init()
  repl_loop(rl, state)
  rl.wait_for_completion()
}

///|
/// * BUG: Cann't read user's input.
/// ```bash
/// moon run cmd
/// ```
/// But what ever I do, it just can't read the input.
fn repl_loop(rl : @rl.T, state : @coc.ReplState) -> Unit {
  rl.question("> ", line => {
    println("You entered: " + line)
    if line == "" {
      repl_loop(rl, state)
    } else if line == ":quit" || line == ":q" {
      println("Goodbye.")
      rl.close()
    } else {
      let step = @coc.repl_process(state, line)
      if step.output != "" {
        println(step.output)
      }
      repl_loop(rl, step.state)
    }
  })
}
