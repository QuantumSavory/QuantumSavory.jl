using Test
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

# Regression probe for the second onchange race discussed in PR 383:
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383#issuecomment-4371250761
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383#issuecomment-4386204614
#
# A watcher wakes for the first `tag!`, immediately waits again on the same
# slot, and schedules a second same-timestamp `tag!` while other watchers are
# still being woken by the first tag. This is the user-facing behavior that must
# remain correct independently of the internal notification primitive.
@testset "register slot onchange wakes after re-wait during tag cascade" begin
    reg = Register(1)
    slot = reg[1]
    sim = get_time_tracker(reg)
    log = Symbol[]

    @resumable function second_tagger(sim)
        @yield timeout(sim, 0)
        tag!(slot, :second)
        push!(log, :second_tag)
    end

    function rewatch_and_schedule_tag(sim)
        p = onchange(slot, Tag)
        @process second_tagger(sim)
        return p
    end

    @resumable function rewatcher(sim)
        @yield onchange(slot, Tag)
        push!(log, :first_wake)
        @yield rewatch_and_schedule_tag(sim)
        push!(log, :second_wake)
    end

    @resumable function passive_watcher(sim, i)
        @yield onchange(slot, Tag)
        push!(log, Symbol(:passive_wake_, i))
    end

    @resumable function first_tagger(sim)
        @yield timeout(sim, 1)
        tag!(slot, :first)
        push!(log, :first_tag)
    end

    @process rewatcher(sim)
    @process passive_watcher(sim, 1)
    @process passive_watcher(sim, 2)
    @process first_tagger(sim)

    run(sim, 2)

    @test log == [
        :first_tag,
        :first_wake,
        :passive_wake_1,
        :passive_wake_2,
        # passive_wake_2 will happen even if there was no second_tag
        :second_tag,
        :second_wake,
    ]
    @test query(slot, :second).tag == Tag(:second)
end
