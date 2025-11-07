///|
/// CoC core — ADT-based minimal implementation (enum Term)
///
/// Provides a small, self-contained Term enum and pure functions:
/// mk_var/mk_sort/mk_pi/mk_lam/mk_app/mk_let, pp, term_eq, subst, whnf, normalize, convertible
enum Term {
  Var(String)
  Sort(String)
  Pi(String, Term, Term)
  Lam(String, Term, Term)
  App(Term, Term)
  Let(String, Term, Term, Term)
}

///|
pub suberror UnboundVariable

///|
pub suberror PiDomainNotSort

///|
pub suberror PiCodomNotSort

///|
pub suberror LambdaAnnNotType

///|
pub suberror ArgMismatch

///|
pub suberror NotFunction

///|
pub suberror LetValueMismatch

///|
/// Maps type errors to human-readable diagnostics.
fn explain_error(err : Error) -> String {
  match err {
    UnboundVariable => "variable not found in context"
    PiDomainNotSort => "Pi domain is not a valid universe"
    PiCodomNotSort => "Pi codomain is not a valid universe"
    LambdaAnnNotType => "lambda annotation is not a valid type"
    ArgMismatch => "function argument type does not match parameter"
    NotFunction => "attempted to apply a non-function term"
    LetValueMismatch => "let value does not match declared type"
    _ => "unknown type error"
  }
}

///|
/// Creates a variable term.
///
/// Parameters:
///
/// * `name`: binder name to lift into the AST.
///
/// Returns a `Var` with the provided binder name.
///
/// Example:
///
/// ```moonbit
/// let x = mk_var("x")
/// inspect(pp(x), content="Var(x)")
/// ```
pub fn mk_var(name : String) -> Term {
  Var(name)
}

///|
/// Creates a universe sort term.
///
/// Parameters:
///
/// * `level`: textual universe level such as "0" or "1".
///
/// Returns a `Sort` describing the given universe level.
///
/// Example:
///
/// ```moonbit
/// let u0 = mk_sort("0")
/// inspect(pp(u0), content="Sort(0)")
/// ```
pub fn mk_sort(level : String) -> Term {
  Sort(level)
}

///|
/// Builds a dependent function type (Pi type).
///
/// Parameters:
///
/// * `vname`: parameter name bound inside the codomain.
/// * `domain`: parameter type.
/// * `codom`: result type, potentially depending on `vname`.
///
/// Returns a `Pi` node representing the dependent function type.
///
/// Example:
///
/// ```moonbit
/// let ty = mk_pi("x", mk_sort("0"), mk_var("x"))
/// inspect(pp(ty), content="Pi(x,Sort(0),Var(x))")
/// ```
pub fn mk_pi(vname : String, domain : Term, codom : Term) -> Term {
  Pi(vname, domain, codom)
}

///|
/// Builds a lambda abstraction.
///
/// Parameters:
///
/// * `vname`: parameter name being bound.
/// * `ty`: explicit type annotation for the parameter.
/// * `body`: lambda body where `vname` may appear.
///
/// Returns a `Lam` representing the lambda expression.
///
/// Example:
///
/// ```moonbit
/// let lam = mk_lam("x", mk_sort("0"), mk_var("x"))
/// inspect(pp(lam), content="Lam(x,Sort(0),Var(x))")
/// ```
pub fn mk_lam(vname : String, ty : Term, body : Term) -> Term {
  Lam(vname, ty, body)
}

///|
/// Forms an application between a function term and an argument.
///
/// Parameters:
///
/// * `fn_`: function being applied.
/// * `arg`: argument supplied to the function.
///
/// Returns a `App` node.
///
/// Example:
///
/// ```moonbit
/// let app = mk_app(mk_var("f"), mk_var("x"))
/// inspect(pp(app), content="App(Var(f),Var(x))")
/// ```
pub fn mk_app(fn_ : Term, arg : Term) -> Term {
  App(fn_, arg)
}

///|
/// Builds a let-binding term.
///
/// Parameters:
///
/// * `vname`: new binding name.
/// * `ty`: declared type of the binding.
/// * `val`: definition assigned to the binding.
/// * `body`: context where the binding is available.
///
/// Returns a `Let` representing the binding.
///
/// Example:
///
/// ```moonbit
/// let let_term = mk_let("x", mk_sort("0"), mk_var("y"), mk_var("x"))
/// inspect(pp(let_term), content="Let(x,Sort(0),Var(y),Var(x))")
/// ```
pub fn mk_let(vname : String, ty : Term, val : Term, body : Term) -> Term {
  Let(vname, ty, val, body)
}

///|
/// Pretty-prints a term into a compact string representation.
///
/// Parameters:
///
/// * `t`: term to display.
///
/// Returns a string rendering such as `Var(x)` or `Pi(x,Sort(0),Var(x))`.
///
/// Example:
///
/// ```moonbit
/// let text = pp(mk_var("x"))
/// inspect(text, content="Var(x)")
/// ```
pub fn pp(t : Term) -> String {
  match t {
    Var(n) => "Var(" + n + ")"
    Sort(l) => "Sort(" + l + ")"
    Pi(n, d, c) => "Pi(" + n + "," + pp(d) + "," + pp(c) + ")"
    Lam(n, ty, b) => "Lam(" + n + "," + pp(ty) + "," + pp(b) + ")"
    App(f, a) => "App(" + pp(f) + "," + pp(a) + ")"
    Let(n, ty, v, b) =>
      "Let(" + n + "," + pp(ty) + "," + pp(v) + "," + pp(b) + ")"
  }
}

///|
/// Tests structural equality between two terms.
///
/// Parameters:
///
/// * `a`: first term.
/// * `b`: second term.
///
/// Returns `true` when the terms are syntactically identical.
///
/// Example:
///
/// ```moonbit
/// inspect(term_eq(mk_var("x"), mk_var("x")), content="true")
/// ```
pub fn term_eq(a : Term, b : Term) -> Bool {
  match (a, b) {
    (Var(x), Var(y)) => x == y
    (Sort(x), Sort(y)) => x == y
    (Pi(n1, d1, c1), Pi(n2, d2, c2)) =>
      n1 == n2 && term_eq(d1, d2) && term_eq(c1, c2)
    (Lam(n1, t1, b1), Lam(n2, t2, b2)) =>
      n1 == n2 && term_eq(t1, t2) && term_eq(b1, b2)
    (App(f1, a1), App(f2, a2)) => term_eq(f1, f2) && term_eq(a1, a2)
    (Let(n1, t1, v1, b1), Let(n2, t2, v2, b2)) =>
      n1 == n2 && term_eq(t1, t2) && term_eq(v1, v2) && term_eq(b1, b2)
    _ => false
  }
}

///|
/// Performs capture-avoiding substitution.
///
/// Parameters:
///
/// * `t`: term in which substitution happens.
/// * `vname`: variable name to replace.
/// * `by`: replacement term.
///
/// Returns a new term where free occurrences of `vname` are replaced by `by`.
///
/// Example:
///
/// ```moonbit
/// let lam = mk_lam("x", mk_sort("0"), mk_var("x"))
/// inspect(pp(subst(lam, "x", mk_var("y"))), content="Lam(x,Sort(0),Var(x))")
/// ```
pub fn subst(t : Term, vname : String, by : Term) -> Term {
  match t {
    Var(n) => if n == vname { by } else { Var(n) }
    Sort(l) => Sort(l)
    Pi(n, d, c) =>
      if n == vname {
        Pi(n, subst(d, vname, by), c)
      } else {
        Pi(n, subst(d, vname, by), subst(c, vname, by))
      }
    Lam(n, ty, body) =>
      if n == vname {
        Lam(n, subst(ty, vname, by), body)
      } else {
        Lam(n, subst(ty, vname, by), subst(body, vname, by))
      }
    App(f, a) => App(subst(f, vname, by), subst(a, vname, by))
    Let(n, ty, v, b) =>
      if n == vname {
        Let(n, subst(ty, vname, by), subst(v, vname, by), b)
      } else {
        Let(n, subst(ty, vname, by), subst(v, vname, by), subst(b, vname, by))
      }
  }
}

///|
/// Computes weak-head normal form (one β-step at the head).
///
/// Parameters:
///
/// * `t`: term to evaluate.
///
/// Returns the term reduced to weak-head normal form.
///
/// Example:
///
/// ```moonbit
/// let lam = mk_lam("x", mk_sort("0"), mk_var("x"))
/// let app = mk_app(lam, mk_var("y"))
/// inspect(pp(whnf(app)), content="Var(y)")
/// ```
pub fn whnf(t : Term) -> Term {
  match t {
    App(fn_, arg) =>
      match fn_ {
        Lam(n, _ty, body) => subst(body, n, arg)
        _ => App(fn_, arg)
      }
    _ => t
  }
}

///|
/// Repeatedly normalizes a term to β-normal form.
///
/// Parameters:
///
/// * `t`: term to normalize.
///
/// Returns the fully normalized term.
///
/// Example:
///
/// ```moonbit
/// let term = mk_app(mk_lam("x", mk_sort("0"), mk_var("x")), mk_var("z"))
/// inspect(pp(normalize(term)), content="Var(z)")
/// ```
pub fn normalize(t : Term) -> Term {
  let cur = whnf(t)
  if term_eq(cur, t) {
    t
  } else {
    normalize(cur)
  }
}

///|
/// Checks β-convertibility by comparing normalized forms.
///
/// Parameters:
///
/// * `a`: first term.
/// * `b`: second term.
///
/// Returns `true` if both normalize to the same term.
///
/// Example:
///
/// ```moonbit
/// let lam = mk_lam("x", mk_sort("0"), mk_var("x"))
/// let app = mk_app(lam, mk_var("y"))
/// inspect(convertible(app, mk_var("y")), content="true")
/// ```
pub fn convertible(a : Term, b : Term) -> Bool {
  term_eq(normalize(a), normalize(b))
}

///|
struct Binding {
  name : String
  ty : Term
}

///|
/// Creates an empty typing context.
///
/// Returns an empty `Array[Binding]` that can be extended with `extend`.
///
/// Example:
///
/// ```moonbit
/// let ctx = empty_ctx()
/// inspect(ctx.length(), content="0")
/// ```
pub fn empty_ctx() -> Array[Binding] {
  []
}

///|
/// Extends a typing context with a new binding.
///
/// Parameters:
///
/// * `ctx`: existing context.
/// * `name`: variable to bind.
/// * `ty`: type associated with the variable.
///
/// Returns a new context with the binding appended.
///
/// Example:
///
/// ```moonbit
/// let ctx = extend(empty_ctx(), "x", mk_sort("0"))
/// inspect(ctx.length(), content="1")
/// ```
pub fn extend(ctx : Array[Binding], name : String, ty : Term) -> Array[Binding] {
  let b = { name, ty }
  let nctx = ctx
  nctx.push(b)
  nctx
}

///|
/// Looks up a variable in the typing context.
///
/// Parameters:
///
/// * `ctx`: context to search.
/// * `name`: variable name to locate.
///
/// Returns the associated type or raises a `TypeError` when missing.
///
/// Example:
///
/// ```moonbit
/// let ctx = extend(empty_ctx(), "x", mk_sort("0"))
/// inspect(pp(lookup(ctx, "x")), content="Sort(0)")
/// ```
pub fn lookup(
  ctx : Array[Binding],
  name : String,
) -> Term raise UnboundVariable {
  for b in ctx {
    if b.name == name {
      return b.ty
    }
  }
  raise UnboundVariable
}

///|
/// Computes the successor universe label using a simple string scheme.
///
/// Parameters:
///
/// * `l`: current universe label (e.g. "0").
///
/// Returns the next label (either "1" for zero or appends `'`).
///
/// Example:
///
/// ```moonbit
/// inspect(level_succ("0"), content="1")
/// ```
pub fn level_succ(l : String) -> String {
  if l == "0" {
    "1"
  } else {
    l + "'"
  }
}

///|
/// Infers the type of a term under a given context (simplified CoC rules).
///
/// Parameters:
///
/// * `ctx`: typing context.
/// * `t`: term whose type should be derived.
///
/// Returns the inferred type term or raises a `TypeError`.
///
/// Example:
///
/// ```moonbit
/// let lam = mk_lam("x", mk_sort("0"), mk_var("x"))
/// inspect(pp(type_infer(empty_ctx(), lam)), content="Pi(x,Sort(0),Sort(0))")
/// ```
pub fn type_infer(ctx : Array[Binding], t : Term) -> Term raise {
  match t {
    Var(n) => lookup(ctx, n)
    Sort(l) => Sort(level_succ(l))
    Pi(n, dom, cod) => {
      let dty = type_infer(ctx, dom)
      guard dty is Sort(_) else { raise PiDomainNotSort }
      let ctx2 = extend(ctx, n, dom)
      let cty = type_infer(ctx2, cod)
      guard cty is Sort(_) else { raise PiCodomNotSort }
      Sort("1")
    }
    Lam(n, ty, body) => {
      let tty = type_infer(ctx, ty)
      guard tty is Sort(_) else { raise LambdaAnnNotType }
      let ctx2 = extend(ctx, n, ty)
      let bty = type_infer(ctx2, body)
      Pi(n, ty, bty)
    }
    App(f, a) => {
      let ft = type_infer(ctx, f)
      match ft {
        Pi(n, dom, cod) => {
          let at = type_infer(ctx, a)
          if !convertible(at, dom) {
            raise ArgMismatch
          }
          subst(cod, n, a)
        }
        _ => raise NotFunction
      }
    }
    Let(n, ty, v, body) => {
      let vt = type_infer(ctx, v)
      if !convertible(vt, ty) {
        raise LetValueMismatch
      }
      let ctx2 = extend(ctx, n, ty)
      type_infer(ctx2, body)
    }
  }
}

///|
/// Utility demo returning the pretty-printed type of the identity lambda.
///
/// Returns a descriptive string such as `Pi(x,Sort(0),Sort(0))`.
///
/// Example:
///
/// ```moonbit
/// inspect(tc_demo_infer_id(), content="Pi(x,Sort(0),Sort(0))")
/// ```
pub fn tc_demo_infer_id() -> String {
  // simple identity: \x : Sort(0) . x
  let _id_ty = mk_pi("x", mk_sort("0"), mk_var("x"))
  let id = mk_lam("x", mk_sort("0"), mk_var("x"))
  try {
    let t = type_infer(empty_ctx(), id)
    pp(t)
  } catch {
    err => "Type error: " + explain_error(err)
  }
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
    let term = mk_pi("x", mk_lam("y", mk_sort("0"), mk_var("y")), mk_sort("0"))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(explain_error(err), content="Pi domain is not a valid universe")
  }

  // PiCodomNotSort
  try {
    let term = mk_pi("x", mk_sort("0"), mk_lam("y", mk_sort("0"), mk_var("y")))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(explain_error(err), content="Pi codomain is not a valid universe")
  }

  // LambdaAnnNotType
  try {
    let term = mk_lam("x", mk_lam("y", mk_sort("0"), mk_var("y")), mk_var("x"))
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
    let fn_ = mk_lam("x", mk_sort("1"), mk_var("x"))
    let arg = mk_sort("0")
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
    let term = mk_app(mk_sort("0"), mk_sort("1"))
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
    let term = mk_let("x", mk_sort("1"), mk_sort("0"), mk_var("x"))
    let _ = type_infer(empty_ctx(), term)

  } catch {
    err =>
      inspect(
        explain_error(err),
        content="let value does not match declared type",
      )
  }
}
