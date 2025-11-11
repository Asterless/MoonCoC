///|
enum Term {
  Var(String)
  Sort(Int)
  Pi(String, Term, Term)
  Lam(String, Term, Term)
  App(Term, Term)
  Let(String, Term, Term, Term)
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
/// inspect(mk_var("x") == mk_var("x"), content="true")
/// inspect(mk_var("x") == mk_var("y"), content="false")
/// ```
pub impl Eq for Term with equal(self : Term, other : Term) -> Bool {
  match (self, other) {
    (Var(x), Var(y)) => x == y
    (Sort(x), Sort(y)) => x == y
    (Pi(n1, d1, c1), Pi(n2, d2, c2)) => n1 == n2 && d1 == d2 && c1 == c2
    (Lam(n1, t1, b1), Lam(n2, t2, b2)) => n1 == n2 && t1 == t2 && b1 == b2
    (App(f1, a1), App(f2, a2)) => f1 == f2 && a1 == a2
    (Let(n1, t1, v1, b1), Let(n2, t2, v2, b2)) =>
      n1 == n2 && t1 == t2 && v1 == v2 && b1 == b2
    _ => false
  }
}

///|
pub impl Show for Term with to_string(t : Term) -> String {
  match t {
    Var(n) => "Var(" + n + ")"
    Sort(l) => "Sort(" + l.to_string() + ")"
    Pi(n, d, c) => "Pi(" + n + "," + d.to_string() + "," + c.to_string() + ")"
    Lam(n, ty, b) =>
      "Lam(" + n + "," + ty.to_string() + "," + b.to_string() + ")"
    App(f, a) => "App(" + f.to_string() + "," + a.to_string() + ")"
    Let(n, ty, v, b) =>
      "Let(" +
      n +
      "," +
      ty.to_string() +
      "," +
      v.to_string() +
      "," +
      b.to_string() +
      ")"
  }
}

///|
pub impl Show for Term with output(t : Term, logger : &Logger) -> Unit {
  logger.write_string(Term::to_string(t))
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
/// inspect(x, content="Var(x)")
/// ```
pub fn mk_var(name : String) -> Term {
  Var(name)
}

///|
/// Creates a universe sort term.
///
/// Parameters:
///
/// * `level`: universe level (0 for Type0, 1 for Type1, ...).
///
/// Returns a `Sort` describing the given universe level.
///
/// Example:
///
/// ```moonbit
/// let u0 = mk_sort(0)
/// inspect(u0, content="Sort(0)")
/// ```
pub fn mk_sort(level : Int) -> Term {
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
/// let ty = mk_pi("x", mk_sort(0), mk_var("x"))
/// inspect(ty, content="Pi(x,Sort(0),Var(x))")
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
/// let lam = mk_lam("x", mk_sort(0), mk_var("x"))
/// inspect(lam, content="Lam(x,Sort(0),Var(x))")
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
/// inspect(app, content="App(Var(f),Var(x))")
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
/// let let_term = mk_let("x", mk_sort(0), mk_var("y"), mk_var("x"))
/// inspect(let_term, content="Let(x,Sort(0),Var(y),Var(x))")
/// ```
pub fn mk_let(vname : String, ty : Term, val : Term, body : Term) -> Term {
  Let(vname, ty, val, body)
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
/// let lam = mk_lam("x", mk_sort(0), mk_var("x"))
/// inspect(subst(lam, "x", mk_var("y")), content="Lam(x,Sort(0),Var(x))")
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
/// let lam = mk_lam("x", mk_sort(0), mk_var("x"))
/// let app = mk_app(lam, mk_var("y"))
/// inspect(whnf(app), content="Var(y)")
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
/// let term = mk_app(mk_lam("x", mk_sort(0), mk_var("x")), mk_var("z"))
/// inspect(normalize(term), content="Var(z)")
/// ```
pub fn normalize(t : Term) -> Term {
  let cur = whnf(t)
  if cur == t {
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
/// let lam = mk_lam("x", mk_sort(0), mk_var("x"))
/// let app = mk_app(lam, mk_var("y"))
/// inspect(convertible(app, mk_var("y")), content="true")
/// ```
pub fn convertible(a : Term, b : Term) -> Bool {
  normalize(a) == normalize(b)
}
