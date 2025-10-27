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
priv enum ParseResult {
  Ok(Term, Int)
  Err(String)
}

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
/// Recursively parses a term from the token stream starting at the provided index.
fn parse_term(tokens : Array[String], start : Int) -> ParseResult {
  if start >= tokens.length() {
    return ParseResult::Err("unexpected end of term")
  }
  let head = tokens[start]
  if head == "var" {
    if start + 1 >= tokens.length() {
      ParseResult::Err("expected name after 'var'")
    } else {
      ParseResult::Ok(mk_var(tokens[start + 1]), start + 2)
    }
  } else if head == "sort" {
    if start + 1 >= tokens.length() {
      ParseResult::Err("expected level after 'sort'")
    } else {
      ParseResult::Ok(mk_sort(tokens[start + 1]), start + 2)
    }
  } else if head == "lam" {
    if start + 1 >= tokens.length() {
      return ParseResult::Err("expected parameter name after 'lam'")
    }
    let name = tokens[start + 1]
    match parse_term(tokens, start + 2) {
      ParseResult::Err(msg) => ParseResult::Err(msg)
      ParseResult::Ok(ty, next) =>
        match parse_term(tokens, next) {
          ParseResult::Err(msg) => ParseResult::Err(msg)
          ParseResult::Ok(body, next2) =>
            ParseResult::Ok(mk_lam(name, ty, body), next2)
        }
    }
  } else if head == "pi" {
    if start + 1 >= tokens.length() {
      return ParseResult::Err("expected parameter name after 'pi'")
    }
    let name = tokens[start + 1]
    match parse_term(tokens, start + 2) {
      ParseResult::Err(msg) => ParseResult::Err(msg)
      ParseResult::Ok(dom, next) =>
        match parse_term(tokens, next) {
          ParseResult::Err(msg) => ParseResult::Err(msg)
          ParseResult::Ok(cod, next2) =>
            ParseResult::Ok(mk_pi(name, dom, cod), next2)
        }
    }
  } else if head == "app" {
    match parse_term(tokens, start + 1) {
      ParseResult::Err(msg) => ParseResult::Err(msg)
      ParseResult::Ok(fn_, next) =>
        match parse_term(tokens, next) {
          ParseResult::Err(msg) => ParseResult::Err(msg)
          ParseResult::Ok(arg, next2) =>
            ParseResult::Ok(mk_app(fn_, arg), next2)
        }
    }
  } else if head == "let" {
    if start + 1 >= tokens.length() {
      return ParseResult::Err("expected name after 'let'")
    }
    let name = tokens[start + 1]
    match parse_term(tokens, start + 2) {
      ParseResult::Err(msg) => ParseResult::Err(msg)
      ParseResult::Ok(ty, next) =>
        match parse_term(tokens, next) {
          ParseResult::Err(msg) => ParseResult::Err(msg)
          ParseResult::Ok(val, next2) =>
            match parse_term(tokens, next2) {
              ParseResult::Err(msg) => ParseResult::Err(msg)
              ParseResult::Ok(body, next3) =>
                ParseResult::Ok(mk_let(name, ty, val, body), next3)
            }
        }
    }
  } else {
    ParseResult::Err("unknown term constructor '" + head + "'")
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
    LookupResult::Missing
  } else {
    let def = defs[idx]
    if def.name == name {
      LookupResult::Found(def.term)
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
    Term::Var(n) =>
      match find_definition(defs, n, 0) {
        LookupResult::Found(def_term) => expand_defs(def_term, defs, depth + 1)
        LookupResult::Missing => term
      }
    Term::Sort(_) => term
    Term::Pi(n, dom, cod) =>
      Term::Pi(n, expand_defs(dom, defs, depth), expand_defs(cod, defs, depth))
    Term::Lam(n, ty, body) =>
      Term::Lam(n, expand_defs(ty, defs, depth), expand_defs(body, defs, depth))
    Term::App(fn_, arg) =>
      Term::App(expand_defs(fn_, defs, depth), expand_defs(arg, defs, depth))
    Term::Let(n, ty, val, body) =>
      Term::Let(
        n,
        expand_defs(ty, defs, depth),
        expand_defs(val, defs, depth),
        expand_defs(body, defs, depth),
      )
  }
}

///|
/// Detects whether a term is one of the stringly-typed error sentinels.
fn is_error_sort(t : Term) -> Bool {
  match t {
    Term::Sort(label) =>
      label == "ERROR:unbound" ||
      label == "ERROR:pi_domain_not_sort" ||
      label == "ERROR:pi_codom_not_sort" ||
      label == "ERROR:lambda_ann_not_type" ||
      label == "ERROR:arg_mismatch" ||
      label == "ERROR:not_function" ||
      label == "ERROR:let_value_mismatch"
    _ => false
  }
}

///|
/// Maps error sentinel terms to human-readable diagnostics.
fn explain_error(t : Term) -> String {
  match t {
    Term::Sort("ERROR:unbound") => "variable not found in context"
    Term::Sort("ERROR:pi_domain_not_sort") =>
      "Pi domain is not a valid universe"
    Term::Sort("ERROR:pi_codom_not_sort") =>
      "Pi codomain is not a valid universe"
    Term::Sort("ERROR:lambda_ann_not_type") =>
      "lambda annotation is not a valid type"
    Term::Sort("ERROR:arg_mismatch") =>
      "function argument type does not match parameter"
    Term::Sort("ERROR:not_function") => "attempted to apply a non-function term"
    Term::Sort("ERROR:let_value_mismatch") =>
      "let value does not match declared type"
    _ => "unknown error"
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
      return ok_step(state, "Usage: def <name> <term...>")
    }
    let name = tokens[1]
    match parse_term(tokens, 2) {
      ParseResult::Err(msg) => ok_step(state, "Parse error: " + msg)
      ParseResult::Ok(term, next) => {
        if next != tokens.length() {
          let extra = tokens[next]
          return ok_step(state, "Unexpected extra token: " + extra)
        }
        let ty = type_infer(state.ctx, term)
        if is_error_sort(ty) {
          ok_step(state, "Type error: " + explain_error(ty))
        } else {
          let def = { name, term, ty }
          let defs = state.defs
          defs.push(def)
          let ctx = extend(state.ctx, name, ty)
          let new_state = { ctx, defs }
          ok_step(new_state, "Defined: " + name + " : " + pp(ty))
        }
      }
    }
  } else if cmd == "infer" {
    match parse_term(tokens, 1) {
      ParseResult::Err(msg) => ok_step(state, "Parse error: " + msg)
      ParseResult::Ok(term, next) => {
        if next != tokens.length() {
          return ok_step(state, "Unexpected extra token in infer command")
        }
        let ty = type_infer(state.ctx, term)
        if is_error_sort(ty) {
          ok_step(state, "Type error: " + explain_error(ty))
        } else {
          ok_step(state, pp(ty))
        }
      }
    }
  } else if cmd == "normalize" {
    match parse_term(tokens, 1) {
      ParseResult::Err(msg) => ok_step(state, "Parse error: " + msg)
      ParseResult::Ok(term, next) => {
        if next != tokens.length() {
          return ok_step(state, "Unexpected extra token in normalize command")
        }
        let expanded = expand_defs(term, state.defs, 0)
        ok_step(state, pp(normalize(expanded)))
      }
    }
  } else if cmd == "whnf" {
    match parse_term(tokens, 1) {
      ParseResult::Err(msg) => ok_step(state, "Parse error: " + msg)
      ParseResult::Ok(term, next) => {
        if next != tokens.length() {
          return ok_step(state, "Unexpected extra token in whnf command")
        }
        let expanded = expand_defs(term, state.defs, 0)
        ok_step(state, pp(whnf(expanded)))
      }
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
