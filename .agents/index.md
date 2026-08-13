# QuantumSavory Agent Knowledge

Load only the route needed for the current task. Context records supported behavior,
current implementation, and explicit gaps based on maintainer decisions, human
documentation, source, tests, examples, and CI. When those sources disagree, preserve
the mismatch for investigation; maintainer-validated intended behavior and human
documentation take precedence over an accidental implementation detail.

`.agents/evals/` is unrelated to this documentation system and excluded from the
context routes. Open it only for evaluation work; do not load or reorganize it while
navigating repository knowledge.

## Context routes

Start with the narrowest route. Open another only when the task crosses that boundary;
each route leads directly to a small set of leaves.

| Need | Open | Do not open |
|---|---|---|
| Register ownership, operations, metadata, and discrete events | [Core context](context/core/index.md) | Backend implementation, transport, zoo, or repository-workflow tasks |
| Backend capability, extension, time, and noise behavior | [Simulation context](context/simulation/index.md) | Public register use or protocol-only work |
| Network topology, metadata, transport, protocol races, and logging | [Network context](context/network/index.md) | State/circuit catalog or backend-only tasks |
| State, circuit, and protocol catalogs and extension playbooks | [Zoo context](context/zoos/index.md) | Core storage, backend internals, or general workflow work |
| Tests, documentation, examples, and benchmarks | [Workflow context](context/workflows/index.md) | Product behavior or subsystem architecture questions |
| Weak-dependency activation and optional integrations | [Optional extensions](context/optional-extensions.md) | Core-only changes with no extension or logging impact |
