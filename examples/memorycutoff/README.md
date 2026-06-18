# Memory Cutoff Tradeoff Explorer

This example studies a small repeater chain where link-level Bell pairs are
generated continuously, intermediate nodes swap entanglement toward the end
users, and cutoff protocols discard memories after a configurable retention
time.

The point of the example is to make the memory-management tradeoff visible:
short retention times discard stale pairs quickly, while long retention times
can improve throughput but allow older qubits to be swapped into end-to-end
pairs.

Files:

1. `1_cutoff_sweep.jl` runs a deterministic sweep over a few retention times
   and prints delivered-pair and stabilizer summaries.
2. `2_wglmakie_interactive.jl` serves a small WGLMakie dashboard with sliders
   for retention time, link success probability, memory `T2`, and simulation
   duration.
3. `setup.jl` contains the reusable simulation setup and summary helpers.

The simulation uses `EntanglerProt`, `SwapperProt`, `EntanglementTracker`,
`CutoffProt`, and `EntanglementConsumer` from `QuantumSavory.ProtocolZoo`.
