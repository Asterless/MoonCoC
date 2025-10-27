# MoonCoc

Minimal Calculus of Constructions (CoC) core written in [MoonBit](https://docs.moonbitlang.com), featuring a pure functional kernel and a prefix-style REPL for quick experiments.

## Highlights

- Self-contained `Term` ADT with constructors, substitution, normalization, and convertibility helpers.
- Lightweight type inference that reports errors via readable sentinel terms.
- Scriptable REPL pipeline (`repl_process`, `repl_run_script`) suited for editors, tests, or future CLI front-ends.
- Snapshot-driven test suite covering β-reduction, normalization, type inference, and REPL commands.

## Installation

Add this package to your MoonBit project:

```bash
moon add Asterless/MoonCoc
```

## Repository Layout

```text
src/
  coc_core_adts.mbt   -- CoC core definitions and inline tests
  coc_repl.mbt        -- REPL state machine and helpers
  coc_test.mbt        -- Snapshot tests and REPL scenarios
cmd/ (optional)       -- Create a CLI entry point if desired
```

The crate exposes public APIs from `src/coc_core_adts.mbt` and `src/coc_repl.mbt`. The `cmd/` directory is empty by default; you can add your own `cmd/main/main.mbt` if you want an interactive shell.

## Using the REPL Programmatically

Import the package in your project (example alias `coc`):

```MoonBit
let state = @coc.repl_init()
let step1 = @coc.repl_process(state, "def id lam x sort 0 var x")
let step2 = @coc.repl_process(step1.state, "infer var id")
// step2.output => "Pi(x,Sort(0),Sort(0))"
```

Running a batch script is equally simple:

```MoonBit
let outputs = @coc.repl_run_script([
  "def id lam x sort 0 var x",
  "normalize app var id var y",
])
```

These helpers make it easy to integrate MoonCoc into editors, tests, or custom tooling.

## License

Licensed under the [Apache-2.0](./LICENSE) license.
