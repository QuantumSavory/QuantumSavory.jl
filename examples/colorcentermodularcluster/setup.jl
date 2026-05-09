# For convenient graph data structures
using Graphs

# For discrete event simulation
using ResumableFunctions
using ConcurrentSim

# For sampling from probability distributions
using Distributions

# Useful for interactive work
# Enables automatic re-compilation of modified codes
isinteractive() && @eval using Revise

# The workhorse for the simulation
using QuantumSavory

##

"""Set the state of the electronic spins to entangled."""
function bk_el_init(env::Environment, rega, regb, conf)
    initialize!([rega[1],regb[1]], conf[:ψᴮᴷ]; time=now(env))
    apply!(rega[1], H; time=now(env))
end

"""Swap between the electronic and nuclear spins of a node."""
function bk_swap(env::Environment, reg, conf)
    # check whether the nuclear register contains anything
    if !isassigned(reg, 2)
        initialize!(reg[2]; time=now(env))
        apply!(reg[2], H)
        # TODO model the need for nuclear spin initialization before entanglement starts
    end
    # perform the CPHASE gate
    apply!([reg[1],reg[2]], CPHASE; time=now(env))
    off = project_traceout!(reg[1], σˣ)
    if rand()>conf[:Fᵐᵉᵃˢ] # TODO this should be declarative in project_traceout or something like that
        off = off%2+1
    end
    return off
end

@resumable function barrettkok(env::Environment, net, nodea, nodeb, conf)
    # check whether this link is already being attempted
    link_resource = net[(nodea, nodeb), :link_queue]
    islocked(link_resource) && return
    # if not, reserve both electronic spins, by using a nongreedy multilock
    espin_slots = [net[nodea, 1], net[nodeb, 1]]
    @yield request(link_resource)
    @yield @process nongreedymultilock(env, espin_slots)
    # wait for a successful entangling attempt (separate attempts not modeled explicitly)
    rega = net[nodea]
    regb = net[nodeb]
    attempts = 1+rand(conf[:𝒟ˢᵘᶜᶜ])
    duration = attempts*conf[:τᵉⁿᵗ]
    @yield timeout(env, duration)
    bk_el_init(env, rega, regb, conf)
    # reserve the nuclear spins, by using a nongreedy multilock
    nspin_slots = [net[nodea, 2], net[nodeb, 2]]
    @yield @process nongreedymultilock(env, nspin_slots)
    # wait for the two parallel swaps from the electronic to nuclear spins
    @yield timeout(env, conf[:τˢʷᵃᵖ])
    r1 = bk_swap(env, rega, conf)
    r2 = bk_swap(env, regb, conf)
    # if necessary, correct the computational basis - currently done by affecting the state,
    # but something that might be better done with a Pauli frame
    r1==2 && apply!(regb[2], Z)
    r2==2 && apply!(rega[2], Z)
    # register that we believe an entanglement was established
    net[(nodea, nodeb), :link_register] = true
    # release locks
    release.(nspin_slots)
    release.(espin_slots)
    release(link_resource)
    #@simlog env "success on $(nodea) $(nodeb) after $(attempts) attempt(s) $(duration)"
end

##

function prep_sim(root_conf)
    graph = grid([2,3])
    traits = [Qubit(),Qubit()]

    bg = [T2Dephasing(root_conf[:T₂ᵉ]), T2Dephasing(root_conf[:T₂ⁿ])]
    net = RegisterNet(graph, [Register(traits,bg) for i in vertices(graph)])

    # compute various derived constants for the simulation
    conf = derive_conf(root_conf)

    # set up ConcurrentSim discrete events simulation
    sim = get_time_tracker(net)

    net[:, :decay_queue] = () -> Resource(sim)
    net[(:,:), :link_queue]    = () -> Resource(sim)
    net[(:,:), :link_register] = false

    for (;src,dst) in edges(net)
        @process barrettkok(sim, net, src, dst, conf)
    end

    observables = [reduce(⊗, [σˣ,fill(σᶻ,n)...]) for n in 1:5]

    net, sim, observables, conf
end

function derive_conf(root_conf; inplace=false)
    ηᵒᵖᵗ = root_conf[:ηᵒᵖᵗ] # the efficiency of the optical path
    ξᴼᴮ = root_conf[:ξᴼᴮ]
    ξᴰᵂ = root_conf[:ξᴰᵂ]
    ξᴱ  = root_conf[:ξᴱ]
    Fᵖᵘʳᶜ = root_conf[:Fᵖᵘʳᶜ]
    ηᵗᵒᵗᵃˡ = ηᵒᵖᵗ * ξᴼᴮ * Fᵖᵘʳᶜ / (Fᵖᵘʳᶜ-1+(ξᴰᵂ*ξᴱ)^-1)

    Pˢᵘᶜᶜ = 0.5 * ηᵗᵒᵗᵃˡ^2
    𝒟ˢᵘᶜᶜ = Geometric(Pˢᵘᶜᶜ)

    τˢʷᵃᵖ = 10/root_conf[:gʰᶠ] # TODO CONSTS could be better than 10x TODO have a more precise factor than 10x

    ψᴮᴷ = (Z₁⊗Z₁ + Z₂⊗Z₂) / √2
    ψᴮᴷ = SProjector(ψᴮᴷ)
    # CONSTS should include imperfections from measurements and from initialization/gates
    # electron measurement infidelity, dark counts, initialization infidelity, rotation gate infidelity
    dep(p,o) = p*o+(1-p)*MixedState(o)
    ψᴮᴷ = dep(root_conf[:Fᵉⁿᵗ],ψᴮᴷ)

    conf = Dict(
        root_conf...,
        :ηᵗᵒᵗᵃˡ=>ηᵗᵒᵗᵃˡ,
        :Pˢᵘᶜᶜ=>Pˢᵘᶜᶜ,
        :𝒟ˢᵘᶜᶜ=>𝒟ˢᵘᶜᶜ,
        :τˢʷᵃᵖ=>τˢʷᵃᵖ,
        :ψᴮᴷ=>ψᴮᴷ,
    )
    if inplace
        merge!(root_conf, conf)
    else
        conf
    end
end

# time is measured in ms
# frequency is measured in kHz

root_conf = Dict(
    # Spin lifetimes (electron and nuclear)
    :T₁ᵉ => 1.,    # 0.1ms if not well cooled, 10ms if cooled, neglected | Transform-Limited Photons From a Coherent Tin-Vacancy Spin in Diamond (Fig. 4c) | 10.1103/PhysRevLett.124.023602
    :T₂ᵉ => 0.01,  # 1μs without dyn decoup, 28μs with | Quantum control of the tin-vacancy spin qubit in diamond (Sec IV and V) | 10.1103/PhysRevX.11.041041
    :T₁ⁿ => 100e3, # generally very large, neglected, example in NV⁻ | A Ten-Qubit Solid-State Spin Register with Quantum Memory up to One Minute | 10.1103/PhysRevX.9.031045
    :T₂ⁿ => 100.,  # 0.1s before dyn decoup, 60s with, example in NV⁻ | A Ten-Qubit Solid-State Spin Register with Quantum Memory up to One Minute | 10.1103/PhysRevX.9.031045

    # Color center emission properties
    :ξᴰᵂ => 0.57, # Debye-Waller for SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.0310210
    :ξᴱ  => 0.8 , # Quantum Efficiency for SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021
    :ξᴼᴮ => 0.8 , # Optical Branching for SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021
    :Fᵖᵘʳᶜ => 10., # Purcell factor, 1 without enhancement, 10 easy, 25 achievable | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021

    :ηᵒᵖᵗ => 0.1, # Optical efficiency from the diamond to the detector

    :gʰᶠ => 42.6e3, # Hyperfine coupling, imposes the duration of the CPHASE gate, 42.6 MHz | Quantum control of the tin-vacancy spin qubit in diamond (end of Sec I) | 10.1103/PhysRevX.11.041041

    # Entangling processes
    # TODO this should be split in pieces and the dynamics should be simulated exactly
    :τᵉⁿᵗ => 0.015, # Duration of a single entanglement attempt (including pumping and waiting for a photon), units of ms
    :Fᵉⁿᵗ => 1.0,   # Entanglement fidelity

    :Fᵐᵉᵃˢ => 0.99, # measurement fidelity

    # TODO not yet used
    #=
    :τᵉᵍᵃᵗᵉ => 0.000, # depends on the electronic gyromag and applied field
    :τⁿᵍᵃᵗᵉ => 0.000, # depends on the nuclear gyromag and applied field, not really used, as these gates are tracked in the pauli frame
    :BK_measurement_duration => 0.004,
    :BK_electron_init_fidelity => 1.,
    :BK_nuclear_init_fidelity => 1.,
    :BK_electron_singleq_fidelity => 1.,
    :BK_nuclear_singleq_fidelity => 1.,
    :BK_swap_gate_fidelity => 1.,
    =#
)
