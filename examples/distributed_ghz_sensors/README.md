# Distributed GHZ Sensors

This example demonstrates how probabilistic entanglement can be turned into a shared GHZ state for distributed quantum sensing, implementing the protocols from ["Utilizing probabilistic entanglement between sensors in quantum networks"](https://journals.aps.org/prapplied/abstract/10.1103/PhysRevApplied.22.064085).

A hub (vertex `S+1`) is connected to `S` remote sensors in a star network. A GHZ state is established across the entangled sensors through the following steps:

1. **Probabilistic entanglement generation**: Each sensor attempts to share a noisy Bell pair with its dedicated hub slot (`EntanglerProt`);
2. **GHZ projection**: Once a batch of links is ready, the hub maps the GHZ stabilizers onto the computational basis by applying CNOTs and a Hadamard, then measures its qubits (`apply!`, `project_traceout!`);
3. **Correction**: Based on the measurement outcomes, the hub sends classical X/Z correction tags to the sensors (`EntanglementUpdateX`, `EntanglementUpdateZ`);
4. **Pauli frame update**: Each sensor applies the announced corrections so the entangled sensors share a proper GHZ state (`EntanglementTracker`).

The two protocols differ only in *when* the hub decides the entanglement-generation phase is over. The `f_tmbl.jl` and `v_tmbl.jl` files each run one round and report the number of entangled sensors and the resulting GHZ fidelity. Both files share the parameters and helpers in `setup.jl`.

All protocols used are from `QuantumSavory.ProtocolZoo`.
## Fixed-Time vs Variable-Time

The core tradeoff is what each protocol holds fixed and what it lets vary:

- **F-TMBL** (Fixed-Time Multiplexing Block Length, `f_tmbl.jl`): every sensor attempts entanglement for a *fixed time window*, after which the hub projects on whatever links succeeded. With per-attempt success probability `p` and a window of `k` attempts, each sensor is entangled at projection time with probability `1 - (1-p)^k`, so the number of entangled sensors is a binomial random variable — it can fall below any useful threshold, or be zero.
- **V-TMBL** (Variable-Time Multiplexing Block Length, `v_tmbl.jl`): sensors keep attempting until *at least μ* links succeed, then the hub projects immediately. The number of entangled sensors is guaranteed `≥ μ`, but the generation time it takes to reach μ is now the random variable.

The paper finds V-TMBL is the better choice when `p` is low (rare successes are worth waiting for), while a short fixed window suffices when `p` is high.
