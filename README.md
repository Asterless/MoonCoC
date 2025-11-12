# MoonCoc | [中文](README_zh.md)

A minimal Calculus of Constructions (CoC) core written in [MoonBit](https://docs.moonbitlang.com). You can use it as a library in your own projects or run it as a standalone interactive application.

## Features

- Pure functional core: includes the `Term` ADT, substitution, reduction, and convertibility checking.
- Type inference: a lightweight type checker with universe hierarchy support and clear error reporting.
- Dual usage modes:
  1. As a library: integrate into any MoonBit project via `moon add`.
  2. As a standalone app: clone the repo and run an interactive REPL.

## How to use

Pick whichever way fits your workflow.

### 1) As a standalone interactive application (for quick try-outs and development)

If you want to quickly try the CoC core or hack on it, clone this repository.

Steps:

1. Clone the repository

   ```powershell
   git clone https://github.com/Asterless/MoonCoc.git
   cd MoonCoc
   ```

2. Run the REPL

   The repo ships with a simple REPL at `cmd/main.mbt`. You can also script inputs via `repl_run_script`:

   ```moonbit
   let outputs = @coc.repl_run_script([
     "def id lam x sort 0 var x",
     "normalize app var id var y",
   ])
   println("Outputs: " + outputs.join(", "))
   ```

   Once you're ready, run `main.mbt`:

   ```powershell
   moon run cmd/main.mbt
   ```

### 2) As a library in your own project

To use MoonCoc's API in your MoonBit project, add it as a dependency.

Steps:

1. Add the dependency

   ```powershell
   moon add Asterless/MoonCoc
   ```

   Then add this import in your `moon.pkg.json`:

   ```json
   {
     "import": [
       {
         "path": "Asterless/MoonCoc/src",
         "alias": "coc"
       }
     ]
   }
   ```

2. Use it in code

   You can call functions like `repl_init` and `repl_process` to drive the core.

   ```moonbit
   fn my_app() {
     // Initialize REPL state
     let state = @coc.repl_init()

     // Define a term
     let step1 = @coc.repl_process(state, "def id lam x sort 0 var x")
     println(step1.output) // => "Defined: id : Pi(x,Sort(0),Sort(0))"

     // Infer its type
     let step2 = @coc.repl_process(step1.state, "infer var id")
     println(step2.output) // => "Pi(x,Sort(0),Sort(0))"
   }
   ```

## Project structure

```text
src/
  term.mbt          # Term data type and ops (Eq, Show, constructors)
  errors.mbt        # Custom error types
  utils.mbt         # Utilities (e.g., universe level helpers)
  typing.mbt        # Typing context and type inference core
  repl.mbt          # REPL implementation
  test.mbt          # Tests
cmd/
  main.mbt          # Entry point for the interactive REPL
```

## Development and contributions

Contributions are welcome. A few guidelines:

- After changes, run `moon info && moon fmt` to update interfaces and format code.
- Before committing, run `moon test` to ensure all tests pass. Use `moon test --update` if your intentional changes affect snapshots.
- Found a bug or have an idea? Open an issue.

## License

Licensed under [Apache-2.0](./LICENSE).
