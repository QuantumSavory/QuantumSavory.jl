# Examples Router

Open the [examples workflow](../.agents/context/workflows/examples.md), then the
context page for the demonstrated subsystem. Examples are executable
documentation; tutorial-local helpers are not supported package APIs.

Prefer the runner prefix corresponding to the mirrored wrapper—for example,
`examples/qtcp_tutorial_1` selects
`test/examples/qtcp_tutorial_1_tests.jl`—over an interactive or plotting script.
Keep setup files reusable, record seeds and environments when repeatability
matters, and keep optional visualization dependencies in the examples
environment.
