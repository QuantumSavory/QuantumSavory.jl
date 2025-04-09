using ReinforcementLearning
using Distributions: Geometric
using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using Graphs



#rand(Geometric(prot.success_prob))+1

Base.@kwdef mutable struct QuantumSwitchEnv <: AbstractEnv
    n::Int = 5
    switch::Register = Register(fill(Qubit(), n), fill(CliffordRepr(), n)) 
    clients::Vector{Register}= [Register(1, CliffordRepr()) for _ in 1:n]

    graph::SimpleGraph = random_regular_graph(n, 2, seed=2)
    reward::Union{Nothing, Float64} = nothing
end

struct SwitchAction{a}
    function SwitchAction(a)
        new{a}()
    end
end
RLBase.action_space(env::QuantumSwitchEnv) = SwitchAction.([:teleport, nothing])
RLBase.reward(env::QuantumSwitchEnv) = env.reward
RLBase.state(env::QuantumSwitchEnv, ::Observation, ::DefaultPlayer) = !isnothing(env.reward)
RLBase.state_space(env::QuantumSwitchEnv) = [false, true]
RLBase.is_terminated(env::QuantumSwitchEnv) = !isnothing(env.reward)
RLBase.reset!(env::QuantumSwitchEnv) = env.reward = nothing

function RLBase.act!(x::QuantumSwitchEnv, action)
    if action == SwitchAction(:teleport)
        x.reward = rand() < 0.01 ? 1 : -10
    elseif action == SwitchAction(nothing)
        x.reward = 0
    else
        @error "unknown action of $action"
    end
end

env = QuantumSwitchEnv()
hook = TotalRewardPerEpisode()
run(RandomPolicy(action_space(env)), env, StopAfterNEpisodes(5), hook)