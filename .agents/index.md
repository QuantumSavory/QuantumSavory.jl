# QuantumSavory Agent Knowledge

Load only the route needed for the current task. Normative intent belongs in the
V-model; implementation context records how the repository currently realizes that
intent. When they disagree, treat the mismatch as evidence to investigate rather than
silently rewriting either side.

## Normative specification

Open the [V-model index](v-model/index.md) when reviewing proposed normative
requirements, observable contracts, acceptance criteria, or verification
traceability. The profile is still draft; do not treat it as confirmed architecture
or contract authority, and do not use working context as a substitute for intended
behavior.

`.agents/evals/` is unrelated to this documentation system and excluded from the
V-model. Open it only for evaluation work; do not load or reorganize it while navigating
repository knowledge.

## Working context

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
