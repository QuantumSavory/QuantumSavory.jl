The manual’s superdense-coding example is the smallest useful pattern because
it includes both the delayed quantum channel and the event-driven control flow.

```julia
using QuantumSavory
using ResumableFunctions
using ConcurrentSim

sim = Simulation()

regA = Register(1)
regB = Register(2)

bell_state = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)
initialize!((regA[1], regB[1]), bell_state)

qc = QuantumChannel(sim, 10.0)

@resumable function alice(env, qc)
    apply!(regA[1], Z)
    put!(qc, regA[1])
end

@resumable function bob(env, qc)
    @yield take!(qc, regB[2])
    apply!((regB[2], regB[1]), CNOT)
    apply!(regB[2], H)

    bit1 = project_traceout!(regB, 2, Z) - 1
    bit2 = project_traceout!(regB, 1, Z) - 1
    println(bit1, bit2)
end

@process alice(sim, qc)
@process bob(sim, qc)
run(sim)
```

What this shows:

- `QuantumChannel(sim, 10.0)` models a channel with 10 units of delay;
- `put!(qc, regA[1])` sends an assigned slot through that channel;
- `@yield take!(qc, regB[2])` suspends Bob until arrival;
- the protocol logic lives in `@resumable` processes, not blocking Julia code.

Two practical rules from the docs:

- the destination slot for `take!` must be empty;
- if in-transit noise matters, construct the channel with a background process.

If you want the exact source of this pattern, read `docs/src/manual.md`.

