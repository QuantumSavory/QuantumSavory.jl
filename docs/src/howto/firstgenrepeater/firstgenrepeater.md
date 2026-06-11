# [First Generation Quantum Repeater](@id First-Generation-Quantum-Repeater-ProtocolZoo)

This how-to guide walks through a simulation of a first-generation quantum repeater chain
using the high-level protocol abstractions from [`QuantumSavory.ProtocolZoo`](@ref "Predefined Networking Protocols").

!!! info "Simpler version of a more detailed example"
    Compared to [the lower-level implementation](@ref First-Generation-Quantum-Repeater),
    the code here is drastically shorter because the entangler and swapper are provided as
    ready-made reusable protocols.
    Reading the low-level version first is worthwhile if you want to understand what is
    happening inside these protocols, or if you want to write your own.

We simulate the same physical setup as the low-level guide:

- A chain of quantum repeater nodes, each holding a small register of qubits;
- Nearest-neighbor entanglement is generated probabilistically by an [`EntanglerProt`](@ref QuantumSavory.ProtocolZoo.EntanglerProt);
- Entanglement is extended end-to-end by a [`SwapperProt`](@ref QuantumSavory.ProtocolZoo.SwapperProt) running on every intermediate node;
- Classical metadata (who is entangled with whom) is kept consistent across the network by an [`EntanglementTracker`](@ref QuantumSavory.ProtocolZoo.EntanglementTracker);
- A custom purifier process distills higher-fidelity pairs whenever two Bell pairs are shared between the same node pair.

The source code is in the [`examples/firstgenrepeater`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/firstgenrepeater) folder.

## Network Setup

The network is the same linear graph used in the low-level example.
Given an array of register sizes (e.g. `sizes = [2,3,4,3,2]`) and a T₂ dephasing time,
`simulation_setup` creates a [`RegisterNet`](@ref) — a graph where each vertex holds a [`Register`](@ref) and a shared discrete-event scheduler:

```julia
sim, network = simulation_setup(sizes, T2)
```

Each qubit is assigned a [`T2Dephasing`](@ref) background process so that stored entanglement decays naturally without any explicit tracking.

## Entangler

[`EntanglerProt`](@ref QuantumSavory.ProtocolZoo.EntanglerProt) is a pre-built process that continuously tries to establish a Bell pair between two neighboring nodes.
One instance runs on every edge of the network:

```julia
for (; src, dst) in edges(network)
    eprot = EntanglerProt(sim, network, src, dst; pairstate = noisy_pair, ...)
    @process eprot()
end
```

```@raw html
<video src="../firstgenrepeater_v2-01.entangler.mp4" autoplay loop muted></video>
```

Internally it searches for a free qubit slot on each endpoint, locks them, waits for the
entanglement attempt, and writes the result into the register using the tag system.
All of that bookkeeping is hidden behind the protocol — compare with the
[manual entangler implementation](@ref First-Generation-Quantum-Repeater) to see
what is being abstracted away.

The `pairstate` argument accepts any symbolic or numerical two-qubit state.
Here we use [`BarrettKokBellPair`](@ref QuantumSavory.StatesZoo.BarrettKokBellPair) from [`StatesZoo`](@ref),
a physically motivated noisy Bell state parametrized by the optical channel efficiencies and dark-count probability of the Barrett-Kok scheme:

```julia
pairstate = BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱)
```

## Swapper

[`SwapperProt`](@ref QuantumSavory.ProtocolZoo.SwapperProt) extends entanglement across the chain by performing Bell measurements on local qubits that are each half of a separate Bell pair.
One instance runs on every node:

```julia
for node in vertices(network)
    sprot = SwapperProt(
        sim, network, node;
        nodeL = <(node), nodeH = >(node),
        chooseL = argmin, chooseH = argmax,
        ...
    )
    @process sprot()
end
```

```@raw html
<video src="../firstgenrepeater_v2-02.swapper.mp4" autoplay loop muted></video>
```

The `nodeL`/`nodeH` predicates tell the swapper which nodes count as "left" and "right"
neighbours respectively.
`chooseL = argmin` and `chooseH = argmax` instruct it to prefer swapping with the
farthest available neighbour on each side, which maximises the reach of the resulting long-range link.

## Entanglement Tracker

After a swap, the two remote endpoints of the newly created long-range link need to be
informed about their new counterpart so that they can coordinate future operations.
[`EntanglementTracker`](@ref QuantumSavory.ProtocolZoo.EntanglementTracker) handles all of this classical messaging automatically:

```julia
for node in vertices(network)
    @process EntanglementTracker(sim, network, node)()
end
```

Without it, the metadata stored on each node's register would become stale after swaps,
and the purifier (or any other consumer of entanglement) would not be able to locate its pairs correctly.
In the low-level example this bookkeeping was done by hand inside the swapper loop;
here it is a separate, reusable process.

## Purifier

The purifier is the one protocol that is still written by hand in this example,
to illustrate how simple it is to build a custom process on top of the ProtocolZoo infrastructure.
It searches for any two Bell pairs shared between the same pair of nodes and
distills them into a single higher-fidelity pair:

```julia
@resumable function purifier(sim, network, nodea, nodeb,
                              purifier_wait_time, purifier_busy_time)
    nround = 0
    while true
        pairs_of_bellpairs = findqubitstopurify(network, nodea, nodeb)
        if isnothing(pairs_of_bellpairs)
            @yield timeout(sim, purifier_wait_time)
            continue
        end
        qa1, qa2, qb1, qb2 = pairs_of_bellpairs
        @yield lock(qa1.slot) & lock(qa2.slot) & lock(qb1.slot) & lock(qb2.slot)
        @yield timeout(sim, purifier_busy_time)
        purifyerror = (:X, :Z)[nround % 2 + 1]
        success = Purify2to1(purifyerror)(qa1.slot, qb1.slot, qa2.slot, qb2.slot)
        if success
            nround += 1
        end
        untag!(qa2.slot, qa2.id)
        untag!(qb2.slot, qb2.id)
        unlock(qa1.slot); unlock(qa2.slot); unlock(qb1.slot); unlock(qb2.slot)
    end
end
```

The key difference from the low-level purifier is the use of the **tag system**:
`queryall` and `query` find qubits by their [`EntanglementCounterpart`](@ref QuantumSavory.ProtocolZoo.EntanglementCounterpart) tag rather than by manually inspecting `:enttrackers` arrays,
and `untag!` removes the tag from consumed qubits rather than writing `nothing` into tracker arrays.

Purifiers are started on every pair of nodes:

```julia
for nodea in vertices(network), nodeb in vertices(network)
    nodeb > nodea && @process purifier(sim, network, nodea, nodeb, ...)
end
```

## Running the Simulation

Once all processes are registered the simulation is advanced with `run(sim, t)`:

```julia
sizes = [2, 3, 4, 3, 2]
T2 = 10.0
sim, network = simulation_setup(sizes, T2)

# start all protocol processes ...

step_ts = range(0, 30, step = 0.1)
for t in step_ts
    run(sim, t)
    notify(obs)
end
```

The three scripts in the `examples/firstgenrepeater` folder build on top of each other:

1. **`1_entangler_example.jl`** — entanglement generation only, no swaps or purification;
2. **`2_swapper_example.jl`** — entanglement generation and swapping, as an interactive web app with Barrett-Kok source sliders;
3. **`3_purifier_example.jl`** — all three layers running together.

## Summary of QuantumSavory Tools

| Tool | Role |
|------|------|
| [`Register`](@ref) / [`RegisterNet`](@ref) | Quantum state storage and network topology |
| [`EntanglerProt`](@ref QuantumSavory.ProtocolZoo.EntanglerProt) | Probabilistic nearest-neighbor Bell pair generation |
| [`SwapperProt`](@ref QuantumSavory.ProtocolZoo.SwapperProt) | Entanglement swapping to extend links |
| [`EntanglementTracker`](@ref QuantumSavory.ProtocolZoo.EntanglementTracker) | Classical messaging to keep metadata consistent after swaps |
| [`Purify2to1`](@ref QuantumSavory.CircuitZoo.Purify2to1) | Two-to-one purification circuit |
| [`T2Dephasing`](@ref) | Background dephasing noise on stored qubits |
| [`BarrettKokBellPair`](@ref QuantumSavory.StatesZoo.BarrettKokBellPair) | Physically motivated noisy entangled state |
