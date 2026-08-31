# MBQC-Based Entanglement Purification

This is the runnable measurement-based quantum computing (MBQC) purification
example from the [QuantumSavory paper](https://arxiv.org/abs/2512.16752). It
implements the protocol in ["Measurement-Based Entanglement Distillation and
Constant-Rate Quantum Repeaters over Arbitrary
Distances"](https://journals.aps.org/prl/abstract/10.1103/2bp8-cdxc).

The protocol uses a `[[n,k,d]]` CSS code. Alice and Bob each prepare an
`(n+k)`-qubit resource state. They consume `n` noisy Bell pairs and, when the
syndrome check passes, keep `k` purified pairs. Each node has a communication
qubit for entanglement generation and a storage qubit for the resource state.

The simulation has four main steps:

1. **Prepare the resource states.** `GraphStateConstructor` builds one graph
   state on each side. It creates non-overlapping edges in parallel and fuses
   them into the storage qubits. `GraphToResource` then applies the local
   Clifford corrections.
2. **Generate the noisy pairs.** `EntanglerProt` creates `n` shared pairs in
   the communication qubits.
3. **Measure the pairs.** `PurifierBellMeasurements` Bell-measures each noisy
   pair half with the matching resource-state qubit. It packs the `XX` and
   `ZZ` outcomes and sends them to the other side.
4. **Check the syndrome.** `MBQCPurificationTracker` combines the local and
   remote outcomes. A zero syndrome is accepted. Bob applies the Pauli X/Z
   corrections, and both sides tag the `k` output pairs. On failure, the
   protocol discards the involved qubits.

The example uses the `[[4,2,2]]` code, so each side has six nodes: four input
nodes and two output nodes. `full_purification_example.jl` first checks perfect
input pairs. It then sweeps over noisy Werner states and records the acceptance
rate and the output fidelity conditioned on acceptance. For input fidelity
`F`, it compares the acceptance rate with
`P_accept = (1 + 3p^4) / 4`, where `p = (4F - 1) / 3`.

Run the example from the repository root:

```sh
julia --project=examples examples/purificationMBQC/full_purification_example.jl
julia --project=examples examples/purificationMBQC/plots.jl
```

Set `QS_TESTRUN=true` before either command for a shorter sweep. The plot script
saves `purificationMBQC-plots.png` in the current directory. The sweep does not
set a random seed, so its empirical points vary between runs.

The order of resource-state preparation and long-range pair generation is a
choice made by this example. Different hardware may use a different order. The
current tracker expects consecutive node numbers on each side, with the chief
node first and matching layouts. It packs at most 63 measurement results into
an integer.

See the
[full How-To guide](https://qs.quantumsavory.org/dev/howto/purificationmbqc/)
for more detail.
