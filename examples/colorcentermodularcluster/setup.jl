# For convenient graph data structures
using Graphs

# For discrete event simulation
using ResumableFunctions
using SimJulia

# For sampling from probability distributions
using Distributions

# Useful for interactive work
# Enables automatic re-compilation of modified codes
using Revise

# The workhorse for the simulation
using QuantumSavory

##

#"""Set the state of the electronic spins to entangled."""
function bk_el_init(env::Environment, rega, regb, conf)
    initialize!([rega[1],regb[1]], conf.BK_electron_entanglement_init_state; time=now(env))
    apply!(rega[1], H; time=now(env))
    # TODO decide whether the H gate is folded into the initialization step
    # TODO H gate error rate
    # TODO split out the various imperfections of the initialization in separate parameters
    # TODO bring the timeout wait in this function
end

#"""Swap between the electronic and nuclear spins of a node"""
function bk_swap(env::Environment, reg, conf)
    # check whether the nuclear register contains anything
    if !isassigned(reg, 2)
        initialize!(reg[2]; time=now(env))
        apply!(reg[2], H)
        # TODO model the need for nuclear spin initialization before entanglement starts
    end
    # perform the CPHASE gate
    apply!([reg[1],reg[2]], CPHASE; time=now(env)) # TODO the following depolarization should be declarative when setting up the system
    # TODO conf.BK_swap_gate_fidelity (on top of wait time induced errors)
    # TODO be careful, the wait time for this gate is already present in the
    # perform the projective measurement on the electron spin
    off = project_traceout!(reg[1], σˣ)
    if rand()>conf.BK_measurement_fidelity # TODO this should be declarative in project_traceout or something like that
        off = off%2+1
    end
    # TODO measurement wait time
    return off
end

@resumable function barrettkok(env::Environment, net, nodea, nodeb, conf)
    # check whether this link is already being attempted
    link_resource = net[(nodea, nodeb), :link_queue]
    !isfree(link_resource) && return
    # if not, reserve both electronic spins, by using a nongreedy multilock
    spin_resources = [net[nodea, :espin_queue], net[nodeb, :espin_queue]]
    @yield request(link_resource)
    @yield @process nongreedymultilock(env, spin_resources)
    # wait for a successful entangling attempt (separate attempts not modeled explicitly)
    rega = net[nodea]
    regb = net[nodeb]
    attempts = 1+rand(conf.BK_success_distribution)
    duration = attempts*conf.BK_electron_entanglement_gentime
    @yield timeout(env, duration)
    bk_el_init(env, rega, regb, conf)
    # reserve the nuclear spins, by using a nongreedy multilock
    nspin_resources = [net[nodea, :nspin_queue], net[nodeb, :nspin_queue]]
    @yield @process nongreedymultilock(env, nspin_resources)
    # wait for the two parallel swaps from the electronic to nuclear spins
    @yield timeout(env, conf.BK_swap_duration)
    r1 = bk_swap(env, rega, conf)
    r2 = bk_swap(env, regb, conf)
    # if necessary, correct the computational basis - currently done by affecting the state # TODO use a pauli frame
    r1==2 && apply!(regb[2], Z)
    r2==2 && apply!(rega[2], Z)
    # register that we believe an entanglement was established
    net[(nodea, nodeb), :link_register] = true
    # release locks
    release.(nspin_resources)
    release.(spin_resources)
    release(link_resource)
    #@simlog env "success on $(nodea) $(nodeb) after $(attempts) attempt(s) $(duration)"
end

##

function prep_sim(root_conf)
    graph = grid([2,3])
    traits = [Qubit(),Qubit()]

    bg = [T2Dephasing(root_conf.T2E), T2Dephasing(root_conf.T2N)]

    net = RegisterNet(graph, [Register(traits,bg) for i in vertices(graph)])

    BK_total_efficiency = root_conf.losses*root_conf.ξ_optical_branching * root_conf.F_purcell / (root_conf.F_purcell-1+(root_conf.ξ_debye_waller*root_conf.ξ_quantum_efficiency)^-1)

    BK_success_prob = 0.5 * BK_total_efficiency^2
    BK_success_distribution = Geometric(BK_success_prob)

    BK_swap_duration = 10/root_conf.hyperfine_coupling # TODO CONSTS could be better than 10x TODO have a more precise factor than 10x

    BK_mem_wait_time = root_conf.BK_mem_wait_factor*mean(BK_success_distribution)*root_conf.BK_electron_entanglement_gentime

    observables = [reduce(⊗, [σˣ,fill(σᶻ,n)...]) for n in 1:5]
    BK_electron_entanglement_init_state = (Z₁⊗Z₁ + Z₂⊗Z₂) / √2
    BK_electron_entanglement_init_state = SProjector(BK_electron_entanglement_init_state)
    # CONSTS should include imperfections from measurements and from initialization/gates
    # electron measurement infidelity, dark counts, initialization infidelity, rotation gate infidelity
    dep(p,o) = p*o+(1-p)*MixedState(o)
    BK_electron_entanglement_init_state = dep(root_conf.BK_electron_entanglement_fidelity,BK_electron_entanglement_init_state)

    conf = (;
        root_conf...,
        BK_total_efficiency,
        BK_success_prob,
        BK_success_distribution,
        BK_swap_duration,
        BK_mem_wait_time,
        BK_electron_entanglement_init_state,
    )

    # set up SimJulia discrete events simulation
    sim = Simulation()

    net[:, :espin_queue] = () -> Resource(sim,1)
    net[:, :nspin_queue] = () -> Resource(sim,1)
    net[:, :decay_queue] = () -> Resource(sim,1)
    net[(:,:), :link_queue]    = () -> Resource(sim,1)
    net[(:,:), :link_register] = false

    for (;src,dst) in edges(net)
        @process barrettkok(sim, net, src, dst, conf)
    end

    net, sim, observables, conf
end

# time is measured in ms
# frequency is measured in kHz

root_conf = (;
    T1E = 1.,    # 0.1ms if not well cooled, 10ms if cooled, neglected | Transform-Limited Photons From a Coherent Tin-Vacancy Spin in Diamond (Fig. 4c) | 10.1103/PhysRevLett.124.023602
    T2E = 0.01,  # 1μs without dyn decoup, 28μs with | Quantum control of the tin-vacancy spin qubit in diamond (Sec IV and V) | 10.1103/PhysRevX.11.041041
    T1N = 100e3, # generally very large, neglected, example in NV⁻ | A Ten-Qubit Solid-State Spin Register with Quantum Memory up to One Minute | 10.1103/PhysRevX.9.031045
    T2N = 100.,  # 0.1s before dyn decoup, 60s with, example in NV⁻ | A Ten-Qubit Solid-State Spin Register with Quantum Memory up to One Minute | 10.1103/PhysRevX.9.031045

    ξ_debye_waller = 0.57, # For SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.0310210
    ξ_quantum_efficiency = 0.8, # For SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021
    ξ_optical_branching = 0.8, # For SnV | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021
    F_purcell = 10., # 1 without enchancement, 10 easy, 25 achieved | Quantum Photonic Interface for Tin-Vacancy Centers in Diamond | 10.1103/PhysRevX.11.031021

    losses = 0.1, # CONSTS should be explicit

    hyperfine_coupling = 42.6e3, # imposes the duration of the CPHASE gate, 42.6 MHz | Quantum control of the tin-vacancy spin qubit in diamond (end of Sec I) | 10.1103/PhysRevX.11.041041
    BK_electron_gate_duration = 0.000, # CONSTS TODO | depends on the electronic gyromag and applied field
    BK_nuclear_gate_duration = 0.000, # CONSTS TODO | depends on the nuclear gyromag and applied field, not really used, as these gates are tracked in the pauli frame

    # TODO this should be split in pieces, the dynamics should be simulated exactly
    BK_electron_entanglement_gentime = 0.015, # units of ms # CONSTS why?
    BK_electron_entanglement_fidelity = 1.0,

    BK_measurement_duration = 0.004, # CONSTS TODO
    BK_measurement_fidelity = 0.99, # CONSTS TODO
    BK_electron_init_fidelity = 1., # CONSTS TODO
    BK_nuclear_init_fidelity = 1., # CONSTS TODO
    BK_electron_singleq_fidelity = 1., # CONSTS TODO
    BK_nuclear_singleq_fidelity = 1., # CONSTS TODO
    BK_swap_gate_fidelity = 1., # CONSTS TODO
    BK_mem_wait_factor = 10, # CONSTS TODO
)
