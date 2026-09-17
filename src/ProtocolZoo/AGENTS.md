# ProtocolZoo Router

Open the [protocol catalog](../../.agents/context/zoos/protocols-catalog.md) for
the existing processes and tag schemas. Open
[add a protocol](../../.agents/context/zoos/add-protocol.md) for changes. For
query, lock, race, or cleanup logic, open the
[protocol development playbook](../../.agents/context/network/protocol-development.md)
directly.

Protocol correctness depends on snapshot revalidation, slot locks, reciprocal
metadata, pair identifiers, and documented constructor parameters. Test
stale-query and modeled cleanup paths as well as the happy path. Current
implementation gaps must remain visible in code and docs.
