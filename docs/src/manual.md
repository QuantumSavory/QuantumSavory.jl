# [Manual](@id manual)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

## Getting Started

### Installation

To use QuantumSavory, make sure you have Julia version 1.10 installed. You can download and install Julia from [the official Julia website](https://julialang.org/downloads/).

Once Julia is setup, QuantumSavory can be installed with the following command in your in your Julia REPL:
```bash
$ julia
julia> ]
pkg> add QuantumSavory
```

#### Optional Dependencies

There are optional packages that you need to install to use the full plotting feature.
- **Makie**: For plotting of registers and processes.
- **GeoMakie**: Enables plotting on a real-world map as a background.

## Basic Demo

Here’s a simple example to demonstrate how superdense coding can be implemented. For more advanced examples and detailed guide, see[How-To Guides](@ref) and [Tutorials](@ref) sections.

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