///|
/// Stores a named definition along with its elaborated term and type.
pub struct Definition {
  name : String
  term : Term
  ty : Term
}

///|
/// Aggregates the typing context and stored definitions for the REPL session.
pub struct ReplState {
  ctx : Array[Binding]
  defs : Array[Definition]
}

///|
/// Bundles the next REPL state together with the textual response.
pub struct ReplStep {
  state : ReplState
  output : String
}

///|
/// Internal result type for parsing prefix-encoded terms.
priv struct ParseResult {
  term : Term
  next : Int
}

///|
priv suberror ParseError String

///|
/// Character code for '0', used in parsing sort levels.
const ZERO_CODE : Int = 48

///|
/// Character code for '9', used in parsing sort levels.
const NINE_CODE : Int = 57

///|
/// Maximum safe integer value for overflow checking (32-bit signed Int).
const MAX_INT : Int = 2147483647

///|
/// Creates a fresh REPL state with an empty context and no definitions.
pub fn repl_init() -> ReplState {
  let ctx = empty_ctx()
  let defs = []
  { ctx, defs }
}

///|
/// Returns a short usage string describing the supported REPL commands.
pub fn repl_help() -> String {
  "help            show supported commands\nctx             print the current context\ndefs            list stored definitions\ndef <name> <term...>   define a term using prefix syntax\ninfer <term...>        infer the type of a term\nnormalize <term...>    normalize a term to beta normal form\nwhnf <term...>         reduce a term to weak-head normal form\nclear           reset context and definitions"
}

///|
/// Splits a line of prefix-encoded input into non-empty whitespace-separated tokens.
fn split_tokens(line : String) -> Array[String] {
  let raw = line.split(" ")
  let tokens = []
  for tok in raw {
    if tok != "" {
      tokens.push(tok.to_string())
    }
  }
  tokens
}

///|
fn parse_sort_level(token : String) -> Int raise ParseError {
  if token == "Type" {
    return 0
  }
  let chars = token.to_array()
  if chars.length() == 0 {
    raise ParseError("invalid sort level: " + token)
  }
  let mut acc = 0
  for ch in chars {
    let code = ch.to_int()
    if code < ZERO_CODE || code > NINE_CODE {
      raise ParseError("invalid sort level: " + token)
    }
    let digit = code - ZERO_CODE
    if acc > (MAX_INT - digit) / 10 {
      raise ParseError("sort level too large: " + token)
    }
    acc = acc * 10 + digit
  }
  acc
}

///|
/// Recursively parses a term from the token stream starting at the provided index.
fn parse_term(
  tokens : Array[String],
  start : Int,
) -> ParseResult raise ParseError {
  if start >= tokens.length() {
    raise ParseError("unexpected end of term")
  }
  let head = tokens[start]
  if head == "var" {
    if start + 1 >= tokens.length() {
      raise ParseError("expected name after 'var'")
    } else {
      { term: mk_var(tokens[start + 1]), next: start + 2 }
    }
  } else if head == "sort" {
    if start + 1 >= tokens.length() {
      raise ParseError("expected level after 'sort'")
    } else {
      let level = parse_sort_level(tokens[start + 1])
      { term: mk_sort(level), next: start + 2 }
    }
  } else if head == "lam" {
    if start + 1 >= tokens.length() {
      raise ParseError("expected parameter name after 'lam'")
    }
    let name = tokens[start + 1]
    let ty_res = parse_term(tokens, start + 2)
    let body_res = parse_term(tokens, ty_res.next)
    { term: mk_lam(name, ty_res.term, body_res.term), next: body_res.next }
  } else if head == "pi" {
    if start + 1 >= tokens.length() {
      raise ParseError("expected parameter name after 'pi'")
    }
    let name = tokens[start + 1]
    let dom_res = parse_term(tokens, start + 2)
    let cod_res = parse_term(tokens, dom_res.next)
    { term: mk_pi(name, dom_res.term, cod_res.term), next: cod_res.next }
  } else if head == "app" {
    let fn_res = parse_term(tokens, start + 1)
    let arg_res = parse_term(tokens, fn_res.next)
    { term: mk_app(fn_res.term, arg_res.term), next: arg_res.next }
  } else if head == "let" {
    if start + 1 >= tokens.length() {
      raise ParseError("expected name after 'let'")
    }
    let name = tokens[start + 1]
    let ty_res = parse_term(tokens, start + 2)
    let val_res = parse_term(tokens, ty_res.next)
    let body_res = parse_term(tokens, val_res.next)
    {
      term: mk_let(name, ty_res.term, val_res.term, body_res.term),
      next: body_res.next,
    }
  } else {
    raise ParseError("unknown term constructor '" + head + "'")
  }
}

///|
/// Helper result used when expanding user-defined names.
priv enum LookupResult {
  Found(Term)
  Missing
}

///|
/// Searches the stored definitions for a matching name, returning its term if found.
fn find_definition(
  defs : Array[Definition],
  name : String,
  idx : Int,
) -> LookupResult {
  if idx >= defs.length() {
    Missing
  } else {
    let def = defs[idx]
    if def.name == name {
      Found(def.term)
    } else {
      find_definition(defs, name, idx + 1)
    }
  }
}

///|
/// Expands references to named definitions while guarding against deep recursion.
fn expand_defs(term : Term, defs : Array[Definition], depth : Int) -> Term {
  if depth > 16 {
    return term
  }
  match term {
    Var(n) =>
      match find_definition(defs, n, 0) {
        Found(def_term) => expand_defs(def_term, defs, depth + 1)
        Missing => term
      }
    Sort(_) => term
    Pi(n, dom, cod) =>
      Pi(n, expand_defs(dom, defs, depth), expand_defs(cod, defs, depth))
    Lam(n, ty, body) =>
      Lam(n, expand_defs(ty, defs, depth), expand_defs(body, defs, depth))
    App(fn_, arg) =>
      App(expand_defs(fn_, defs, depth), expand_defs(arg, defs, depth))
    Let(n, ty, val, body) =>
      Let(
        n,
        expand_defs(ty, defs, depth),
        expand_defs(val, defs, depth),
        expand_defs(body, defs, depth),
      )
  }
}

///|
/// Concatenates an array of strings with newline separators.
fn join_lines(lines : Array[String], idx : Int) -> String {
  if idx >= lines.length() {
    ""
  } else if idx == lines.length() - 1 {
    lines[idx]
  } else {
    lines[idx] + "\n" + join_lines(lines, idx + 1)
  }
}

///|
/// Formats all stored definitions as human-readable lines.
fn render_defs(defs : Array[Definition]) -> String {
  if defs.length() == 0 {
    "(no definitions)"
  } else {
    let lines = []
    for d in defs {
      let line = d.name + " : " + pp(d.ty) + " = " + pp(d.term)
      lines.push(line)
    }
    join_lines(lines, 0)
  }
}

///|
/// Formats the current typing context as `name : type` lines.
fn render_ctx(ctx : Array[Binding]) -> String {
  if ctx.length() == 0 {
    "(empty context)"
  } else {
    let lines = []
    for b in ctx {
      let line = b.name + " : " + pp(b.ty)
      lines.push(line)
    }
    join_lines(lines, 0)
  }
}

///|
/// Convenience helper that pairs a state with its textual output.
fn ok_step(state : ReplState, output : String) -> ReplStep {
  { state, output }
}

///|
/// Processes a single REPL command and returns the next state plus output.
pub fn repl_process(state : ReplState, line : String) -> ReplStep {
  let tokens = split_tokens(line)
  if tokens.length() == 0 {
    return ok_step(state, "")
  }
  let cmd = tokens[0]
  if cmd == "help" {
    ok_step(state, repl_help())
  } else if cmd == "ctx" {
    ok_step(state, render_ctx(state.ctx))
  } else if cmd == "defs" {
    ok_step(state, render_defs(state.defs))
  } else if cmd == "clear" {
    ok_step(repl_init(), "state cleared")
  } else if cmd == "def" {
    if tokens.length() < 3 {
      ok_step(state, "Usage: def <name> <term...>")
    } else {
      let name = tokens[1]
      try {
        let res = parse_term(tokens, 2)
        if res.next != tokens.length() {
          let extra = tokens[res.next]
          ok_step(state, "Unexpected extra token: " + extra)
        } else {
          // Now we call type_infer inside the same try block
          let ty = type_infer(state.ctx, res.term)
          let def = { name, term: res.term, ty }
          let defs = state.defs
          defs.push(def)
          let ctx = extend(state.ctx, name, ty)
          let new_state = { ctx, defs }
          ok_step(new_state, "Defined: " + name + " : " + pp(ty))
        }
      } catch {
        ParseError(msg) => ok_step(state, "Parse error: " + msg)
        err => ok_step(state, "Type error: " + explain_error(err))
      }
    }
  } else if cmd == "infer" {
    try {
      let res = parse_term(tokens, 1)
      if res.next != tokens.length() {
        ok_step(state, "Unexpected extra token in infer command")
      } else {
        let ty = type_infer(state.ctx, res.term)
        ok_step(state, pp(ty))
      }
    } catch {
      ParseError(msg) => ok_step(state, "Parse error: " + msg)
      err => ok_step(state, "Type error: " + explain_error(err))
    }
  } else if cmd == "normalize" {
    try {
      let res = parse_term(tokens, 1)
      if res.next != tokens.length() {
        ok_step(state, "Unexpected extra token in normalize command")
      } else {
        let expanded = expand_defs(res.term, state.defs, 0)
        ok_step(state, pp(normalize(expanded)))
      }
    } catch {
      ParseError(msg) => ok_step(state, "Parse error: " + msg)
    }
  } else if cmd == "whnf" {
    try {
      let res = parse_term(tokens, 1)
      if res.next != tokens.length() {
        ok_step(state, "Unexpected extra token in whnf command")
      } else {
        let expanded = expand_defs(res.term, state.defs, 0)
        ok_step(state, pp(whnf(expanded)))
      }
    } catch {
      ParseError(msg) => ok_step(state, "Parse error: " + msg)
    }
  } else {
    ok_step(state, "Unknown command: " + cmd)
  }
}

///|
/// Executes a sequence of commands and returns the collected outputs.
pub fn repl_run_script(lines : Array[String]) -> Array[String] {
  run_script(lines, 0, repl_init(), [])
}

///|
/// Tail-recursive worker that threads the state through the script.
fn run_script(
  lines : Array[String],
  idx : Int,
  state : ReplState,
  outputs : Array[String],
) -> Array[String] {
  if idx >= lines.length() {
    outputs
  } else {
    let step = repl_process(state, lines[idx])
    let outs = outputs
    outs.push(step.output)
    run_script(lines, idx + 1, step.state, outs)
  }
}

///|
test "parse_sort_level_success" {
  inspect(parse_sort_level("Type"), content="0")
  inspect(parse_sort_level("7"), content="7")
  inspect(parse_sort_level("42"), content="42")
}

///|
test "parse_sort_level_error" {
  try {
    let _ = parse_sort_level("4a")
    inspect(
      "Expected a parse error, but none was raised.",
      content="sort-level-invalid-no-error",
    )
  } catch {
    ParseError(msg) => inspect(msg, content="invalid sort level: 4a")
    _ => ()
  }
}

///|
test "parse_sort_level_overflow" {
  // Test that very large numbers are rejected with overflow protection
  try {
    let _ = parse_sort_level("99999999999999999999")
    inspect(
      "Expected overflow error, but none was raised.",
      content="sort-level-overflow-no-error",
    )
  } catch {
    ParseError(msg) =>
      inspect(msg, content="sort level too large: 99999999999999999999")
    _ => ()
  }
}

///|
test "parse_term_success" {
  // Test successful parsing of a simple term
  let tokens1 = ["var", "x"]
  let res = parse_term(tokens1, 0)
  inspect(res.next, content="2")

  // Test successful parsing of a complex term
  let tokens2 = ["lam", "x", "sort", "Type", "var", "x"]
  let res = parse_term(tokens2, 0)
  inspect(res.next, content="6")
}

///|
test "parse_term_error_eof" {
  // Test error: unexpected end of term
  let tokens = []
  try {
    let _ = parse_term(tokens, 0)
    inspect(
      "Expected a parse error, but none was raised.",
      content="parse-eof-no-error",
    )
  } catch {
    ParseError(msg) => inspect(msg, content="unexpected end of term")
    _ => ()
  }
}

///|
test "parse_term_error_missing_name" {
  // Test error: expected name after 'var'
  let tokens = ["var"]
  try {
    let _ = parse_term(tokens, 0)
    inspect(
      "Expected a parse error, but none was raised.",
      content="parse-no-name-no-error",
    )
  } catch {
    ParseError(msg) => inspect(msg, content="expected name after 'var'")
    _ => ()
  }
}

///|
test "parse_term_error_unknown_constructor" {
  // Test error: unknown term constructor
  let tokens = ["foo", "bar"]
  try {
    let _ = parse_term(tokens, 0)
    inspect(
      "Expected a parse error, but none was raised.",
      content="parse-unknown-no-error",
    )
  } catch {
    ParseError(msg) => inspect(msg, content="unknown term constructor 'foo'")
    _ => ()
  }
}

///|
test "repl_process_help" {
  let initial_state = repl_init()
  let step = repl_process(initial_state, "help")
  inspect(
    step.output,
    content="help            show supported commands\nctx             print the current context\ndefs            list stored definitions\ndef <name> <term...>   define a term using prefix syntax\ninfer <term...>        infer the type of a term\nnormalize <term...>    normalize a term to beta normal form\nwhnf <term...>         reduce a term to weak-head normal form\nclear           reset context and definitions",
  )
}

///|
test "repl_process_initial_state" {
  let initial_state = repl_init()
  // Test "ctx" on initial state
  let step_ctx = repl_process(initial_state, "ctx")
  inspect(step_ctx.output, content="(empty context)")

  // Test "defs" on initial state
  let step_defs = repl_process(initial_state, "defs")
  inspect(step_defs.output, content="(no definitions)")
}

///|
test "repl_process_def" {
  let initial_state = repl_init()
  // Test successful "def"
  let step1 = repl_process(initial_state, "def my_type sort 0")
  inspect(step1.output, content="Defined: my_type : Sort(1)")

  // Test "defs" after def
  let step2 = repl_process(step1.state, "defs")
  inspect(step2.output, content="my_type : Sort(1) = Sort(0)")

  // Test "ctx" after def
  let step3 = repl_process(step1.state, "ctx")
  inspect(step3.output, content="my_type : Sort(1)")
}

///|
test "repl_process_errors" {
  let initial_state = repl_init()
  // Test "infer" with unbound variable (type error)
  let step_type_error = repl_process(initial_state, "infer var x")
  inspect(
    step_type_error.output,
    content="Type error: variable not found in context",
  )

  // Test "def" with parse error
  let step_parse_error = repl_process(initial_state, "def bad lam x")
  inspect(
    step_parse_error.output,
    content="Parse error: unexpected end of term",
  )
}

///|
test "repl_process_clear" {
  let initial_state = repl_init()
  let step1 = repl_process(initial_state, "def my_type sort 0")
  // Test "clear"
  let step2 = repl_process(step1.state, "clear")
  inspect(step2.output, content="state cleared")
  inspect(step2.state.defs.length(), content="0")
  inspect(step2.state.ctx.length(), content="0")
}

///|
test "repl_process_unknown_and_empty" {
  let initial_state = repl_init()
  // Test unknown command
  let step_unknown = repl_process(initial_state, "foo bar")
  inspect(step_unknown.output, content="Unknown command: foo")

  // Test empty input
  let step_empty = repl_process(initial_state, "")
  inspect(step_empty.output, content="")
}
