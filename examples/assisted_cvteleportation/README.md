# Assisted CV Teleportation

This example implements the assisted continuous-variable teleportation protocol
from <https://arxiv.org/abs/quant-ph/0604027> using
[Gabs.jl](https://github.com/QuantumSavory/Gabs.jl) as the Gaussian backend.

The tutorial script in `setup.jl` walks through the protocol in four steps:

1. Build a three-node network of continuous-variable registers for Alice, Bob,
   and Charlie.
2. Prepare a random coherent input state together with the shared three-mode
   entangled Gaussian resource.
3. Let Alice and Charlie perform their homodyne measurements and send the
   classical outcomes to Bob.
4. Have Bob apply the displacement correction that reconstructs the teleported
   state.

At the end of the script, the example prints the initial Gaussian state and
Bob's final Gaussian state. They should be very similar, with the remaining
difference coming from finite squeezing in the shared resource.

The squeezing strength is controlled by the `RESOURCE_SQUEEZE` constant near the
top of `setup.jl`. Increasing it makes the teleportation closer to ideal.
