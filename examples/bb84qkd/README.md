# BB84 Quantum Key Distribution with an Intercept-Resend Eavesdropper

A prepare-and-measure BB84 key exchange over a three-node chain: Alice, an
eavesdropper (Eve), and Bob. Alice sends random Pauli eigenstates through the
quantum channel; Eve intercepts and reprepares each pulse with a tunable
probability; Bob measures in a random basis. Basis sifting and parameter
estimation happen over the classical messaging plane, which is forwarded through
Eve's node like any other traffic.

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals:
1. Two bounded single runs (with and without eavesdropping) comparing QBER;
2. A static CairoMakie sweep of the intercept probability against the `p/4` theory;
3. An interactive GLMakie dashboard with live sliders for Eve's intercept
   probability and the source rate.

Without an eavesdropper the sifted key is error free; an intercept-resend
eavesdropper acting on a fraction `p` of the pulses induces a QBER of `p/4`.

Documentation:

- [The "How To" doc page on the BB84 example](https://qs.quantumsavory.org/dev/howto/bb84qkd/)
- [`QuantumSavory` register networks](https://qs.quantumsavory.org/dev/register_networks/)
- [`QuantumSavory` classical messaging](https://qs.quantumsavory.org/dev/classical_messaging/)
