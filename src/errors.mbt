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
pub fn explain_error(err : Error) -> String {
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
