# UUID Entanglement Tracking

This example compares the existing history-based entanglement tracker with the
UUID-based protocol path.

The UUID path assigns an integer identity to each generated Bell pair. After a
swap, the measured-out swapper slots keep route records, so late update/delete
messages can still be forwarded by UUID even if those physical slots have
already been reused.

Run the demo with:

```bash
julia --project=examples examples/uuid_entanglement_tracking/setup.jl
```

The script runs a three-node chain with two link-level Bell pairs and one swap
at the middle node. It reports the final end-to-end Bell-pair fidelity checks
for both tracking approaches.
