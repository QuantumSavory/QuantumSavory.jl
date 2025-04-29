using QuantumSavory
using Plots
##

probs = exp10.(range(-3, stop=0, length=30))

t_init = 0.0
Δt = 2.0
t_finish = Δt*3.0

obs_factory = []
obs_canonical = []
obs_sequential = []
obs_piecemaker = []

for mem_depolar_prob in probs
    decoherence_rate = - log(1 - mem_depolar_prob)

    # --- factory ---
    regState = Register(3, QuantumOpticsRepr())
    regA = Register([Qubit() for _ in 1:3], [Depolarization(1/decoherence_rate/2) for _ in 1:3])
    regB = Register([Qubit() for _ in 1:3], [Depolarization(1/decoherence_rate/2) for _ in 1:3]) #, fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))

    net = RegisterNet([regState, regA, regB]) # network layout
    sim = get_time_tracker(net)

    initialize!(net[1][1:3], StabilizerState("XXX ZIZ IZZ"); time=t_init)
    bell = StabilizerState("XX ZZ")
    for i in 1:3
        initialize!((net[2][i], net[3][i]), bell; time=t_init+Δt*i)
    end

    # BSM + corrections
    for i in 1:3
        apply!((net[1][i], net[2][i]), CNOT; time=t_init+t_finish)
        apply!(net[1][i], H; time=t_init+t_finish)
        zmeas1 = project_traceout!(net[1][i], σᶻ) 
        zmeas2 = project_traceout!(net[2][i], σᶻ) 

        if zmeas2==2 apply!(net[3][i], X) end 
        if zmeas1==2 apply!(net[3][i], Z) end
    end

    # measure
    obs = observable(net[3][1:3], projector(StabilizerState("XXX ZIZ IZZ")); time=t_init+t_finish)
    @info "factory obs: $(obs)"
    push!(obs_factory, real(obs))

    # --- piecemaker ---
    regA = Register(fill(Qubit(), 4), fill(QuantumOpticsRepr(), 4), fill(Depolarization(1/decoherence_rate), 4))
    regB = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))

    net = RegisterNet([regA, regB]) # network layout
    sim = get_time_tracker(net)

    initialize!(net[1][4], X1; time=t_init+Δt)
    bell = StabilizerState("XX ZZ")
    for i in 1:3
        initialize!((net[1][i], net[2][i]), bell; time=t_init+Δt*i)
        apply!((net[1][4], net[2][i]), CNOT; time=t_init+Δt*i)
        zmeas = project_traceout!(net[1][i], σᶻ)
        if zmeas==2 apply!(net[2][i], X) end 
    end

    # trace out piecemaker
    xmeas = project_traceout!(net[1][4], σˣ)
    if xmeas==2 apply!(net[2][1], Z) end

    # measure
    obs = observable(net[2][1:3], projector(StabilizerState("XXX ZIZ IZZ")); time=t_init+t_finish)
    @info "factory obs: $(obs)"
    push!(obs_piecemaker, real(obs))

    # --- canonical ---
    regA = Register([Qubit() for _ in 1:3], [Depolarization(1/decoherence_rate/2) for _ in 1:3])
    regB = Register([Qubit() for _ in 1:3], [Depolarization(1/decoherence_rate/2) for _ in 1:3])

    net = RegisterNet([regA, regB]) # network layout
    sim = get_time_tracker(net)

    bell = StabilizerState("XX ZZ")
    for i in 1:3
        initialize!((net[1][i], net[2][i]), bell; time=t_init+Δt*i)
    end

    # CZ + corrections at the end
    for i in 2:3
        apply!((net[1][1], net[1][i]), ZCZ; time=t_init+t_finish)
    end
    for i in 1:3
        zmeas = project_traceout!(net[1][i], σˣ) 
        if zmeas==2 apply!(net[2][i], Z) end
    end

    # measure
    obs = observable(net[2][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+t_finish)
    @info "canonical obs: $(obs)"
    push!(obs_canonical, real(obs))


    # --- sequential ---
    # regA = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))
    # regB = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))

    # net = RegisterNet([regA, regB]) # network layout
    # sim = get_time_tracker(net)

    # bell = StabilizerState("XX ZZ")
    # for i in 1:3
    #     initialize!((net[1][i], net[2][i]), bell; time=t_init+Δt*i)
    # end

    # # CZ + corrections immediately
    # for i in 2:3
    #     apply!((net[1][1], net[2][i]), ZCZ; time=t_init+Δt*i)
    #     zmeas = project_traceout!(net[1][i], σˣ) 
    #     if zmeas==2 apply!(net[2][i], Z) end
    # end
    # zmeas = project_traceout!(net[1][1], σˣ) 
    # if zmeas==2 apply!(net[2][1], Z) end


    # # measure
    # obs = observable(net[2][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+t_finish)
    # @info "sequential obs: $(obs)"
    # push!(obs_sequential, real(obs))
end

p = plot(
    probs,
    [obs_factory, obs_canonical, obs_piecemaker],
    title="GHZ factory vs canonical",
    xlabel="Memory depolarization probability",
    ylabel="Fidelity",
    label=["factory" "canonical" "piecemaker"],
    xscale=:log10,
    legend=:topright,
    ticks=:native,
    grid=true,
)
display(p)
#savefig("GHZ_factory_vs_canonical.png")

## Depolarizing channel on GHZ state and graph GHZ state
t_init = 0.0
Δt = 10.0

mem_depolar_prob = 0.1
decoherence_rate = - log(1 - mem_depolar_prob)

reg_GHZ = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))
reg_graphGHZ = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))

net = RegisterNet([reg_GHZ, reg_graphGHZ]) # network layout
sim = get_time_tracker(net)

initialize!(net[1][1:3], StabilizerState("XXX ZIZ IZZ"); time=t_init)
initialize!(net[2][1:3], StabilizerState("XZZ ZXI ZIX"); time=t_init)

obsGHZ = observable(net[1][1:3], projector(StabilizerState("XXX ZIZ IZZ")); time=t_init+Δt)
obsgraphGHZ = observable(net[2][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+Δt)

@info "GHZ obs: $(obsGHZ)"
@info "graphGHZ obs: $(obsgraphGHZ)"


## test depolarizing channel on graph GHZ state
create_at_end = 0 # set to 0 to create at the beginning
t_init = 0.0
Δt = 10.0

mem_depolar_prob = 0.1
decoherence_rate = - log(1 - mem_depolar_prob)

reg_graphGHZ = Register([Qubit(), Qubit(), Qubit()], [Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate)])
net = RegisterNet([reg_graphGHZ]) 

initialize!(net[1][1:3], reduce(⊗, fill(Z1, 3)); time=t_init) # "bell pair halves |0>"

for i in 1:3
    apply!(net[1][i], H; time=t_init+create_at_end*Δt)
    if i>1 apply!((net[1][1], net[1][i]), ZCZ; time=t_init+create_at_end*Δt) end
end

obsgraphGHZ = real(observable(net[1][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+Δt))

@info "graphGHZ fidelity: $(obsgraphGHZ)"

## Depolarizing channel UNTIL creation of GHZ
t_init = 0.0
Δt = 10.0

mem_depolar_prob = 0.1
decoherence_rate = - log(1 - mem_depolar_prob)

reg_GHZ = Register([Qubit(), Qubit(), Qubit()], [Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate)])
reg_graphGHZ = Register([Qubit(), Qubit(), Qubit()], [Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate)])

net = RegisterNet([reg_GHZ, reg_graphGHZ]) # network layout
sim = get_time_tracker(net)

initialize!(net[1][1:3], StabilizerState("XXX ZIZ IZZ"); time=t_init)
initialize!(net[2][1:3], StabilizerState("XZZ ZXI ZIX"); time=t_init)

obsGHZ = observable(net[1][1:3], projector(StabilizerState("XXX ZIZ IZZ")); time=t_init+Δt)
obsgraphGHZ = observable(net[2][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+Δt)

@info "GHZ obs: $(obsGHZ)"
@info "graphGHZ obs: $(obsgraphGHZ)"


## 
using QuantumSavory

t_init = 0.0
Δt = 10.0

mem_depolar_prob = 0.1
decoherence_rate = - log(1 - mem_depolar_prob)

regA = Register(fill(Qubit(), 2), fill(Depolarization(1/decoherence_rate), 2))
regB = Register(1, Depolarization(1/decoherence_rate))
regC = Register(1, Depolarization(1/decoherence_rate))

net = RegisterNet([regA, regB, regC]) # network layout
sim = get_time_tracker(net)

initialize!(regA[1], Z1; time=t_init)
initialize!(regB[1], Z1; time=t_init)

# initialize rest of the registers --> if depolarizing channels were correlated in regA, then regA[2] and regC[1] will differ
initialize!(regA[2], X1; time=t_init+Δt)
initialize!(regC[1], X1; time=t_init+Δt)

fidelA1 = observable(regA[1], projector(Z1); time=t_init+Δt)
fidelA2 = observable(regA[2], projector(X1); time=t_init+Δt)

fidelB = observable(regB[1], projector(Z1); time=t_init+Δt)
fidelC = observable(regC[1], projector(X1); time=t_init+Δt)

@info fidelA1 == fidelB
@info fidelA2 == fidelC

## test noise channel with 2 qubits

t_init = 0.0
res0 = []
res1 = []
mem_depolar_prob = 0.1
decoherence_rate = - log(1 - mem_depolar_prob)
for Δt in 0:10

    for create_at_end in [0,1] # 0 => apply CZ at the beginning, 1 => apply CZ at Δt

        switch = Register([Qubit(), Qubit()], [Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate)])
        client = Register([Qubit(), Qubit()], [Depolarization(1/decoherence_rate), Depolarization(1/decoherence_rate)])

        net = RegisterNet([switch, client]) # network layout
        sim = get_time_tracker(net)

        bell = StabilizerState("XX ZZ")
        for i in 1:2
            initialize!((net[1][i], net[2][i]), bell; time=t_init)
        end

        apply!((net[1][1], net[1][2]), ZCZ; time=t_init+create_at_end*Δt)
        for i in 1:2
            zmeas = project_traceout!(net[1][i], σˣ) 
            if zmeas==2 apply!(net[2][i], Z) end
        end

        # measure
        fidel = observable(net[2][1:2], projector(StabilizerState("XZ ZX")); time=t_init+10)

        if create_at_end == 0
            push!(res0, real(fidel))
        else
            push!(res1, real(fidel))
        end
    end
end
plot(
    times,
    [res1, res0],
    title="GHZ factory vs canonical",
    xlabel="Time (s)",
    ylabel="Fidelity",
    label=["res1" "res0"],
    legend=:topright,
    ticks=:native,
    grid=true,
)
savefig("2graph.png")

## test noise channel with 3 qubits

regA = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))
regB = Register(fill(Qubit(), 3), fill(QuantumOpticsRepr(), 3), fill(Depolarization(1/decoherence_rate), 3))

net = RegisterNet([regA, regB]) # network layout
sim = get_time_tracker(net)

bell = StabilizerState("XX ZZ")
for i in 1:3
    initialize!((net[1][i], net[2][i]), bell; time=t_init)
end

# CZ + corrections at the end
for i in 2:3
    apply!((net[1][1], net[2][i]), ZCZ; time=t_init)
end
for i in 1:3
    zmeas = project_traceout!(net[1][i], σˣ) 
    if zmeas==2 apply!(net[2][i], Z) end
end

# measure
obs = observable(net[2][1:3], projector(StabilizerState("XZZ ZXI ZIX")); time=t_init+Δt)
@info "canonical obs: $(obs)"
