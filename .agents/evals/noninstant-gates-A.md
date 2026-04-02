The tutorial documents four different approaches, and it explicitly says they
are not necessarily equivalent.

1. Apply an instantaneous gate and then wait.
   This is the simplest manual approximation.
2. Wait and then apply an instantaneous gate.
   This gives different physics when noise acts during the waiting period.
3. Use `NonInstantGate`.
   Example:

   ```julia
   using QuantumSavory: NonInstantGate
   apply!([reg[1], reg[2]], NonInstantGate(CNOT, 1.0))
   ```

   This is a convenient “gate plus duration” wrapper. The docs describe it as
   applying the gate instantaneously and then waiting, so it gives you only the
   initial and final state, not samples during the gate.
4. Model the gate as Hamiltonian evolution with
   `ConstantHamiltonianEvolution(...)`.
   This is the right choice when the actual continuous-time dynamics matter and
   you want a more faithful physical model.

The important point is that these choices differ once background noise is in
play. “Gate now then wait”, “wait then gate”, and “continuous evolution” can
produce measurably different outcomes.

So the selection rule is:

- use the simple approximations when they are a deliberate modeling choice;
- use Hamiltonian evolution when you need the gate process itself to carry the
  physics.

See `docs/src/tutorial/noninstantgate.md` for the full comparison.

