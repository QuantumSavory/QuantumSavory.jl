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
saves `purificationMBQC-plots.png` in the current directory.

## Interactive hardware-source experiment

Run the GLMakie example in a desktop session, using Julia 1.12 or later:

```sh
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --threads=2,1 --project=examples examples/purificationMBQC/interactive.jl
```

The window starts running immediately. Each run prepares fresh resource states
with `BarrettKokBellPairW` local links and distributes four long-range pairs from
`GenqoMultiplexedCascadedBellPairW`. It uses the same purification pipeline as the
Werner-state example. Sliders control the five Barrett–Kok source parameters and
the four Genqo parameters. One immutable snapshot is taken before each run, so a
slider change affects the next run. Pause finishes the current run; closing the
window stops further runs. Clear history also discards an in-flight result.

Each point is one complete protocol attempt. The horizontal axis is simulated
completion time in source attempt periods, on a logarithmic scale. Blue points
show the mean Bell fidelity of the two accepted output pairs. Red crosses on the
"Rejected" band represent nonzero syndromes; those trials have no output fidelity.
The plot retains the last 100 results. Hover over a point to inspect its settings.
The visible-window statistics include acceptance, mean accepted fidelity, and
retained pairs per source attempt period. Clear history after changing settings
to estimate performance for a single configuration.

Both weighted source traces are used as heralding probabilities. Their normalized
states are converted to the protocol's Bell convention, with an additional
Hadamard for the local graph edges. At real mode overlap these states are exactly
Bell diagonal; a reconstruction check verifies this before Clifford trajectory
sampling. Every generated pair samples independently from that mixture. Thus an
individual trajectory has output fidelity 0, ½, or 1, and averaging accepted
trajectories estimates the conditional ensemble fidelity. This is not the
mixed-state fidelity of a single experimental heralding record.

Try these comparisons, allowing the window to collect many runs at each setting:

- Reduce local mode overlap to see errors in resource preparation affect both
  acceptance and output fidelity.
- With long-range losses present, increase mean photon number to study the
  generation-time versus fidelity tradeoff. The slider stays in `0.001 ≤ N ≤ 0.2`.
- Reduce local transmission with zero dark counts. The heralding time changes,
  while the conditional Barrett–Kok fidelity stays fixed.

Gates, measurements, and memories are ideal. Local and long-range source attempts
both take one time unit; no physical clock rate or propagation delay is assumed.
The Genqo weight is the supplied single-mode, fixed-click-pattern model of the
multiplexed cascaded source. No extra mode count or click-pattern factor is added.

Set `QS_TESTRUN=true` for three runs followed by automatic window closure. The
automated wrapper also checks source normalization and frame conversion, ideal
outputs, noisy acceptance/rejection, history retention, pause/resume, and live
slider snapshots. It needs a display (or Xvfb on Linux).

The order of resource-state preparation and long-range pair generation is a
choice made by this example. Different hardware may use a different order. The
current tracker expects consecutive node numbers on each side, with the chief
node first and matching layouts. It packs at most 63 measurement results into
an integer.

See the
[full How-To guide](https://qs.quantumsavory.org/dev/howto/purificationmbqc/)
for more detail.
