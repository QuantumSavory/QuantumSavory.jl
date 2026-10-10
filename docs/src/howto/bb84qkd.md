# BB84 Quantum Key Distribution

This How-To simulates the prepare-and-measure BB84 quantum key distribution
protocol on a three-node chain, including an active intercept-resend
eavesdropper. It showcases quantum transport over `QuantumChannel`s, classical
coordination over the forwarded messaging plane, and live Makie dashboards.

The full source is in
[`examples/bb84qkd`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/bb84qkd).

## Model

The network is a `path_graph(3)` of single-qubit registers: Alice (node 1), Eve
(node 2), and Bob (node 3). Quantum pulses travel on the quantum channels of the
two links, while classical messages (basis announcements and sifting replies)
are routed with `permit_forward=true`, so Eve's message buffer transparently
forwards the classical traffic of the other two nodes. Qubits are simulated in
`CliffordRepr`: signal states are Pauli eigenstates (`Z1`/`Z2` for the Z basis,
`X1`/`X2` for the X basis) and measurements are projective traces onto `σᶻ` or
`σˣ`.

## Protocol

Each round proceeds as follows:

1. **Prepare.** Alice initializes her qubit in a random basis and random bit and
   puts it on the quantum channel toward Eve.
2. **Attack.** With probability `p`, Eve measures the pulse in a random basis
   and reprepares a fresh qubit in the observed eigenstate before forwarding it
   (intercept-resend); otherwise she forwards the pulse untouched.
3. **Measure.** Bob takes the pulse and measures it in a random basis.
4. **Sift.** Bob announces his basis choice to Alice over the classical plane;
   Alice replies with the keep/discard decision, attaching her bit value on kept
   rounds for parameter estimation.
5. **Estimate.** Bob compares the kept bits and accumulates the sifted key
   length and the running quantum bit error rate (QBER) in a `BB84Stats`
   accumulator.

For an intercept-resend attack on a fraction `p` of the pulses, Eve chooses
the wrong basis with probability `1/2`. Conditional on that choice, Bob's bit
in the sifted key disagrees with Alice's with probability `1/2`, giving an
ideal QBER of `p/4`. With `p=0`, the sifted key is error free. The example's
test wrappers check these limits.

This is an educational sifting and error-rate simulation, not a deployable
secret-key system. Alice's retained bits are disclosed for error statistics;
authenticated classical communication, reconciliation and privacy
amplification are outside the example's scope.

## Scripts

- `1_single_run.jl` runs two bounded simulations, with `p=0` and `p=1`, exposing
  the resulting QBERs for the test suite.
- `2_sweep_viz.jl` sweeps `p` from 0 to 1 and draws a static CairoMakie figure
  comparing the simulated QBER to the `p/4` theory line, plus the sifted key
  length per run.
- `3_makie_interactive.jl` displays a live GLMakie dashboard: the network layout,
  the running QBER, the growing sifted key, and sliders that retune Eve's
  intercept probability and the source period while the simulation advances.

Run them from the repository root with the examples project, e.g.
`julia --project=examples examples/bb84qkd/3_makie_interactive.jl`. Setting
`QS_TESTRUN=true` shortens the interactive run for the automated test suite.
