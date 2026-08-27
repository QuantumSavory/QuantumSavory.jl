# Qumode-Qubit teleportation through a homodyne measurement

Here we go through a quick example to show interesting dynamics that go beyond simple qubits.

A quarter-period Jaynes–Cummings interaction maps ``|Z_1F_0\rangle`` to
``(|Z_1F_0\rangle-i|Z_2F_1\rangle)/\sqrt{2}``. Measuring the normalized
quadrature ``\hat{x}=(a+a^\dagger)/\sqrt{2}`` with result ``x`` leaves the
qubit proportional to ``|Z_1\rangle-i\sqrt{2}x|Z_2\rangle``. An ``X`` rotation
removes this known back-action. This short measurement-and-feed-forward
primitive is related to transduction and teleportation.

```@example
using QuantumSavory

register = Register([Qubit(), Qumode()])
initialize!(register[1:2], Z1 ⊗ F0)

interaction = Pm ⊗ Create + Pp ⊗ Destroy
# some common operators also have Unicode definitions, for instance:
# interaction = σ₋ ⊗ Create + σ₊ ⊗ Destroy
quarter_period = exp(-im * (π / 4) * interaction)
apply!(register[1:2], quarter_period)

x = project_traceout!(register[2], HomodyneMeasurement([0.0]))
if !isapprox(x, 0; atol = 1e-12)
    correction = exp(im * atan(sqrt(2) * x) * X)
    apply!(register[1], correction)
end

fidelity = observable(register[1], SProjector(Z1))
```