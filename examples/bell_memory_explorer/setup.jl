using QuantumSavory
using QuantumSavory.StatesZoo

const BELL_XX = tensor(X, X)
const BELL_YY = tensor(Y, Y)
const BELL_ZZ = tensor(Z, Z)

"""
    bell_memory_trace(; F=0.95, T2=100.0, tmax=300.0, samples=121)

Prepare a depolarized Bell pair in two T2-limited memories and sample its
stabilizer expectations over time.
"""
function bell_memory_trace(;
    F = 0.95,
    T2 = 100.0,
    tmax = 300.0,
    samples = 121,
    representation = QuantumOpticsRepr,
)
    reg = Register(
        [Qubit(), Qubit()],
        [representation(), representation()],
        [T2Dephasing(T2), T2Dephasing(T2)],
    )
    initialize!(reg[1:2], DepolarizedBellPair(; F); time = 0.0)

    times = collect(range(0.0, tmax; length = samples))
    xx = [real(observable(reg[1:2], BELL_XX; something = 0.0, time = t)) for t in times]
    yy = [real(observable(reg[1:2], BELL_YY; something = 0.0, time = t)) for t in times]
    zz = [real(observable(reg[1:2], BELL_ZZ; something = 0.0, time = t)) for t in times]
    fidelity = @. (1 + xx - yy + zz) / 4

    (; time = times, xx, yy, zz, fidelity)
end
