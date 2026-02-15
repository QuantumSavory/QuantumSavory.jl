# MBQC-Based Entanglement Purification

This example demonstrates measurement-based quantum computing (MBQC) entanglement purification, implementing the protocol from ["Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"](https://arxiv.org/abs/2410.18564).

The protocol uses a [4,2] CSS code to distill 2 high-fidelity Bell pairs from 4 noisy Bell pairs through the following steps:

1. **Graph state construction**: Build graph states on both Alice's and Bob's sides using parallel entanglement generation and fusion (`GraphStateConstructor`);
2. **Resource state preparation**: Convert graph states to resource states via local Clifford corrections (`GraphToResource`);
3. **Bell pair distribution**: Distribute noisy entangled pairs between Alice and Bob (`EntanglerProt`);
4. **Purification**: Perform Bell measurements and syndrome-based error detection to identify successfully purified pairs (`PurifierBellMeasurements`, `MBQCPurificationTracker`).

The `full_purification_example.jl` file runs the complete pipeline and verifies the output fidelity of the purified pairs.

All protocols used are from `QuantumSavory.ProtocolZoo`.
