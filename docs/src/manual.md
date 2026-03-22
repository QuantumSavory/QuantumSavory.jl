# [Manual](@id manual)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

This manual is the first guided tutorial for QuantumSavory. It walks through a
small, complete simulation so you can see the core pieces of the package
together before moving on to more specialized pages.

## What You Will Build

In this tutorial, Alice and Bob use a shared Bell pair plus a transmitted qubit
to implement superdense coding. The example is small, but it introduces:

- registers and register slots,
- symbolic state initialization,
- a quantum channel with delay,
- `@resumable` processes, and
- running a discrete-event simulation.

## Installation

To use QuantumSavory, install Julia 1.10 or later and then add the package from
the Julia REPL:

```bash
$ julia
julia> ]
pkg> add QuantumSavory
```

### Optional Dependencies

There are optional packages that you need to install to use the full plotting feature.
- **Makie**: For plotting of registers and processes.
- **Tyler**: Enables plotting on a real-world map as a background.

## First Simulation

Paste the example below into a fresh Julia session. It creates the simulation,
sets up the initial entanglement resource, defines the local processes for
Alice and Bob, and runs the event loop.

```@example
using QuantumSavory
using ResumableFunctions
using ConcurrentSim

sim = Simulation()

# regA for Alice and regB for Bob
regA = Register(1)
regB = Register(2)

# Entangle Alice's and Bob's first qubits
bell_state = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)
initialize!((regA[1], regB[1]), bell_state)

# Channel with delay
qc = QuantumChannel(sim, 10.0)

# Alice wants to send "10"
@resumable function alice(env, qc)
    println("Alice: Encoding 10 at $(now(env))")
    apply!(regA[1], Z)
    put!(qc, regA[1])
end

# Bob receives the qubit and decodes it
@resumable function bob(env, qc)
    @yield take!(qc, regB[2])  # Wait for the qubit from Alice
    apply!((regB[2], regB[1]), CNOT)
    apply!(regB[2], H)

    bit1 = project_traceout!(regB, 2, Z) - 1
    bit2 = project_traceout!(regB, 1, Z) - 1
    println("Bob decoded the bits at $(now(env)): ", bit1, bit2)
end

@process alice(sim, qc)
@process bob(sim, qc)
run(sim)
```

Bob should decode the two classical bits that Alice encoded into her half of
the Bell pair.

## What To Notice

- The initial Bell pair is expressed symbolically.
- The channel delay is handled by the discrete-event simulator.
- Alice and Bob are written as resumable processes rather than ordinary
  blocking code.
- The example is small, but it already uses the same abstractions as larger
  protocol simulations.

## Where To Go Next

- Continue with [Explanations](@ref) if you want the conceptual model.
- Continue with [Tutorials](@ref) for focused follow-up lessons.
- Continue with [How-To Guides](@ref) for larger end-to-end workflows.
