using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames
using CSV
using Profile
using NetworkLayout



@resumable function init_state(sim)
    @yield timeout(sim, 1.)
    initialize!(slot[1], Z1; time=now(sim))
    res = observable(slot[1], projector(Z1); time=now(sim))
    @info res
end

mem_depolar_prob = 0.5
r_depol =  - log(1 - mem_depolar_prob)
print(r_depol)
slot = Register(1, Depolarization(1/r_depol))

sim = get_time_tracker(slot)

@process init_state(sim)
run(sim)

