# MBQC-Based Entanglement Purification

This example demonstrates measurement-based quantum computing (MBQC) entanglement purification, implementing the protocol from ["Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"](https://journals.aps.org/prl/abstract/10.1103/2bp8-cdxc).

The protocol uses a [n, k, d] CSS code to distill k high-fidelity Bell pairs from n noisy Bell pairs through the following steps:

1. **Graph state construction**: Build graph states on both Alice's and Bob's sides using parallel entanglement generation and fusion (`GraphStateConstructor`);
2. **Resource state preparation**: Convert graph states to resource states via local Clifford corrections (`GraphToResource`);
3. **Bell pair distribution**: Distribute noisy entangled pairs between Alice and Bob (`EntanglerProt`);
4. **Purification**: Perform Bell measurements and syndrome-based error detection to identify successfully purified pairs (`PurifierBellMeasurements`, `MBQCPurificationTracker`).

The `full_purification_example.jl` file runs the complete pipeline and verifies the output fidelity of the purified pairs using a [4, 2, 2] code. It also sweeps over a range of input fidelities, and `plots.jl` graphs the success probability and output fidelity against the input fidelity.

Note that the ordering of steps shown in the example (e.g. long-range entanglement generation/graph state generation) is somewhat arbitrary and may vary depending on hardware constraints.

All protocols used are from `QuantumSavory.ProtocolZoo`.

## Success Probability Analysis

For the [4,2,2] code with depolarizing parameter `p`, the success probability follows from enumerating all 4-pair Pauli error configurations and keeping those with even X- and Z-parity. With `a = (1+3p)/4` and `b = (1-p)/4`, the five accepted symmetry classes are:

- **IIII**: `a⁴`
- **Two identical non-identity errors** (e.g. XXII, ZZII, YYII): `18a²b²`
- **Two pairs of different errors** (e.g. XXZZ, XXYY, ZZYY): `18b⁴`
- **All four errors identical** (e.g. XXXX, ZZZZ, YYYY): `3b⁴`
- **One each of I, X, Y, Z**: `24ab³`

Summing gives `P_succ = a⁴ + 18a²b² + 24ab³ + 21b⁴ = (1 + 3p⁴) / 4`.
