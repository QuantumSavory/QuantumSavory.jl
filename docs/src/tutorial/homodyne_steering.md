# Qubit steering through a homodyne measurement

A quarter-period Jaynes–Cummings interaction maps ``|Z_1F_0\rangle`` to
``(|Z_1F_0\rangle-i|Z_2F_1\rangle)/\sqrt{2}``. Measuring the normalized
quadrature ``\hat{x}=(a+a^\dagger)/\sqrt{2}`` with result ``x`` leaves the
qubit proportional to ``|Z_1\rangle-i\sqrt{2}x|Z_2\rangle``. An ``X`` rotation
removes this known back-action. This short measurement-and-feed-forward
primitive is related to transduction and teleportation.

```jldoctest
using QuantumSavory

register = Register([Qubit(), Qumode()])
initialize!(register[1:2], Z1 ⊗ F0)

interaction = σ₋ ⊗ Create + σ₊ ⊗ Destroy
quarter_period = exp(-im * (π / 4) * interaction)
apply!(register[1:2], quarter_period)

x = project_traceout!(register[2], HomodyneMeasurement([0.0]))
if !isapprox(x, 0; atol = 1e-12)
    correction = exp(im * atan(sqrt(2) * x) * X)
    apply!(register[1], correction)
end

fidelity = real(observable(register[1], SProjector(Z1)))
println(isapprox(fidelity, 1; atol = 1e-7))

# output
true
```

No random seed is needed: the correction uses whichever homodyne value was
sampled, and the final fidelity is one for every outcome. `QuantumOpticsRepr`
models the homodyne measurement by diagonalizing the quadrature in its finite
Fock basis, so its discrete spectrum approximates a continuous quadrature
measurement.
