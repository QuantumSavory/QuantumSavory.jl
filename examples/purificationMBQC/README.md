# MBQC-Based Entanglement Purification

This example demonstrates measurement-based quantum computing (MBQC) entanglement purification, implementing the protocol from ["Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"](https://journals.aps.org/prl/abstract/10.1103/2bp8-cdxc).

The protocol uses a [n, k, d] CSS code to distill k high-fidelity Bell pairs from n noisy Bell pairs through the following steps:

1. **Graph state construction**: Build graph states on both Alice's and Bob's sides using parallel entanglement generation and fusion (`GraphStateConstructor`);
2. **Resource state preparation**: Convert graph states to resource states via local Clifford corrections (`GraphToResource`);
3. **Bell pair distribution**: Distribute noisy entangled pairs between Alice and Bob (`EntanglerProt`);
4. **Purification**: Perform Bell measurements and syndrome-based error detection to identify successfully purified pairs (`PurifierBellMeasurements`, `MBQCPurificationTracker`).

The `full_purification_example.jl` file runs the complete pipeline and verifies the output fidelity of the purified pairs using a [4, 2, 2] code.

Note that the ordering of steps shown in the example (e.g. long-range entanglement generation/graph state generation) is somewhat arbitrary and may vary depending on hardware constraints.

All protocols used are from `QuantumSavory.ProtocolZoo`.
