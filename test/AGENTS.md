# Test Router

Open the [testing workflow](../.agents/context/workflows/testing.md), then the
single subsystem context page whose contract is under test.

`test/runtests.jl` discovers files ending in `_tests.jl` and defaults to the
`general` group. Run from the repository root, for example:

```sh
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["general/querywait"])'
```

Use `examples/*`, `plotting/*`, or `jet` only when their separate environment is
needed. Make assertions deterministic where practical, and record any backend or
platform coverage the test does not provide.
