using Test, Logging
using QuantumSavory, ConcurrentSim, ResumableFunctions

@testset "Channel readiness and arrival broadcasts" begin
    for quantum in (false, true), delay in (0.0, 1.0)
        sim = Simulation()
        ch = quantum ? QuantumChannel(sim, delay) : QuantumSavory.ClassicalChannel{Tag}(sim, delay)
        source, destination = Register(2), Register(2)
        initialize!(source[1], Z1) # Vacuum is still an arriving mode.
        initialize!(source[2], Z2)
        arrivals = Tuple{Int,Float64}[]
        @test channel_delay(ch) == delay
        @test !isready(ch)

        @resumable function observe(sim, ch, pending, id)
            @yield pending
            push!(arrivals, (id, now(sim)))
            @yield onchange(ch)
            push!(arrivals, (id, now(sim)))
        end
        # Register before sending, even though the observer processes start later.
        pending = (onchange(ch), onchange(ch))
        put!(ch, quantum ? source[1] : Tag(:first))
        @test !isready(ch) # Even zero-delay transport needs a simulation step.
        for id in 1:2
            @process observe(sim, ch, pending[id], id)
        end
        @resumable function send_second(sim)
            @yield timeout(sim, 2)
            put!(ch, quantum ? source[2] : Tag(:second))
        end
        @resumable function receive(sim)
            for i in 1:2
                @yield timeout(sim, delay + 2(i-1) - now(sim); priority=-1)
                @test isready(ch)
                if quantum
                    @yield take!(ch, destination[i])
                    @test !isassigned(source[i])
                    @test observable(destination[i], Z) ≈ (i == 1 ? 1 : -1)
                else
                    msg = @yield take!(ch)
                    @test msg == Tag(i == 1 ? :first : :second)
                end
                @test !isready(ch)
            end
        end
        @process send_second(sim)
        @process receive(sim)
        @test_logs min_level=Logging.Warn run(sim)
        @test sort(arrivals) == [(1, delay), (1, delay+2), (2, delay), (2, delay+2)]
    end
end

@testset "Channel notifications do not replay ready items" begin
    sim = Simulation()
    ch = QuantumSavory.ClassicalChannel{Tag}(sim, 0)
    run(sim, put!(ch, Tag(:old)))
    @test isready(ch)
    wakes = Float64[]
    pending = onchange(ch)
    @resumable function observe(sim)
        @yield pending
        push!(wakes, now(sim))
    end
    @process observe(sim)
    run(sim, take!(ch))
    run(sim, 1)
    @test isempty(wakes) # Neither existing contents nor receipt is a new arrival.
    put!(ch, Tag(:new))
    run(sim, 2)
    @test wakes == [1.0]
    @test isready(ch)
end

@testset "Channel notifications compose with buffers and tags" begin
    net = RegisterNet([Register(2), Register(2)]; classical_delay=1, quantum_delay=2)
    sim = get_time_tracker(net)
    cc, qc = channel(net, 1=>2), qchannel(net, 1=>2)
    mb, reg = messagebuffer(net, 2), net[2]
    wakes = Float64[]
    @resumable function receiver(sim)
        @yield onchange(qc) | onchange(mb) | onchange(reg, Tag)
        push!(wakes, now(sim))
        @test querydelete!(mb, :hello).tag == Tag(:hello)
        @test !isready(cc) # The message buffer owns classical receipt.
        @test !isready(qc)
        while !isready(qc)
            @yield onchange(qc)
        end
        @yield take!(qc, reg[1])
        @test observable(reg[1], Z) ≈ -1
        match = @yield query_wait(reg, :stored)
        @test match.tag == Tag(:stored)
        push!(wakes, now(sim))
    end
    @resumable function sender(sim)
        put!(cc, Tag(:hello))
        initialize!(net[1][1], Z2)
        put!(qc, net[1][1])
        @yield timeout(sim, 3)
        tag!(reg[1], :stored)
    end
    @process receiver(sim)
    @process sender(sim)
    @test_logs min_level=Logging.Warn run(sim)
    @test wakes == [1.0, 3.0]
    @test !isready(qc) # The abandoned OR branch did not consume the state.
end

@testset "Message buffers still accept raw delay queues" begin
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    queue = DelayQueue{Tag}(sim, 1)
    mb = MessageBuffer(net, 1, [(src=2, channel=queue)])
    put!(queue, Tag(:hello))
    run(sim)
    @test querydelete!(mb, :hello).src == 2
    @test isnothing(query(mb, :hello))
end
