using Test
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

# Regression probe for the first onchange race reported in PR 383:
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383
#
# The public contract is that a task already waiting on a register slot's tag
# changes should wake when `tag!` happens at the same simulation timestamp.
@testset "register slot onchange wakes for a same-timestamp tag" begin
    reg = Register(1)
    slot = reg[1]
    sim = get_time_tracker(reg)
    log = Symbol[]

    @resumable function watcher(sim)
        @yield timeout(sim, 1)
        push!(log, :wait_requested)
        @yield onchange(slot, Tag)
        push!(log, :wait_finished)
    end

    @resumable function tagger(sim)
        @yield timeout(sim, 1)
        tag!(slot, :ready)
        push!(log, :tagged)
    end

    @process watcher(sim)
    @process tagger(sim)

    run(sim, 2)

    @test log == [:wait_requested, :tagged, :wait_finished]
    @test query(slot, :ready).tag == Tag(:ready)
end
