# ASPEN-Net entanglement distribution

Run `julia --project=examples examples/aspen_net/1_entanglement_distribution.jl`
from the repository root. The seeded example runs 40 slots with two sources,
one central station, and one memory per source. A consumer frees confirmed
pairs before the next slot; the final display lists outcomes and timing.

`AspenEntanglerProt` selects the smallest buffer length for which both sources
have a photon with probability at least `coincidence_prob`. Each buffer keeps
only its first heralded photon. All slots use the same absolute clock;
`photon_time` and the network's classical delays determine confirmation arrival.
Both memories remain locked until both confirmations arrive.

This minimal model assumes ideal lossless optics and threshold detection.
False heralds leave vacuum instead of the target Ψ⁺ Bell pair; lowering
`central_fraction` suppresses two-photon events at the cost of fewer heralds.
Plain-text and HTML displays show slot outcomes and timing.
