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
/// let ctx = extend(empty_ctx(), "x", mk_sort(0))
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
/// let ctx = extend(empty_ctx(), "x", mk_sort(0))
/// inspect(lookup(ctx, "x"), content="Sort(0)")
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
/// let lam = mk_lam("x", mk_sort(0), mk_var("x"))
/// inspect(type_infer(empty_ctx(), lam), content="Pi(x,Sort(0),Sort(0))")
/// ```
pub fn type_infer(ctx : Array[Binding], t : Term) -> Term raise {
  match t {
    Var(n) => lookup(ctx, n)
    Sort(level) => Sort(level_succ(level))
    Pi(n, dom, cod) => {
      let dom_ty = type_infer(ctx, dom)
      match dom_ty {
        Sort(dom_level) => {
          let ctx2 = extend(ctx, n, dom)
          let cod_ty = type_infer(ctx2, cod)
          match cod_ty {
            Sort(cod_level) => Sort(@cmp.maximum(dom_level, cod_level))
            _ => raise PiCodomNotSort
          }
        }
        _ => raise PiDomainNotSort
      }
    }
    Lam(n, ty, body) => {
      let ann_ty = type_infer(ctx, ty)
      match ann_ty {
        Sort(_) => {
          let ctx2 = extend(ctx, n, ty)
          let body_ty = type_infer(ctx2, body)
          Pi(n, ty, body_ty)
        }
        _ => raise LambdaAnnNotType
      }
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
  let _id_ty = mk_pi("x", mk_sort(0), mk_var("x"))
  let id = mk_lam("x", mk_sort(0), mk_var("x"))
  try {
    let t = type_infer(empty_ctx(), id)
    t.to_string()
  } catch {
    err => "Type error: " + explain_error(err)
  }
}
