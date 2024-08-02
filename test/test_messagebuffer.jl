@testitem "Message Buffer" tags=[:messagebuffer] begin
    using QuantumSavory: tag_types
    using QuantumSavory.ProtocolZoo
    using ResumableFunctions, ConcurrentSim

    net = RegisterNet([Register(3), Register(2), Register(3)])
    env = get_time_tracker(net);
    @resumable function receive_tags(env)
        while true
            mb = messagebuffer(net, 2)
            @yield wait(mb)
            msg = querydelete!(mb, :second_tag, ❓, ❓)
            if isnothing(msg)
                # println("nothing")
            else
                #println("$(msg.tag) received from node $(msg.src)")
            end
        end
    end
    @resumable function send_tags(env)
        @yield timeout(env, 1.0)
        put!(channel(net, 1=>2), Tag(:my_tag))
        @yield timeout(env, 2.0)
        put!(channel(net, 3=>2), Tag(:second_tag, 123, 456))
    end
    @process send_tags(env);
    @process receive_tags(env);
    run(env, 10)

    @test query(messagebuffer(net, 2), :second_tag, ❓, ❓) === nothing
    @test query(messagebuffer(net, 2), :my_tag).tag == Tag(:my_tag)

    ##

    net = RegisterNet([Register(4), Register(4)])
    sim = get_time_tracker(net)
    proc1 = put!(channel(net, 2=>1), SwitchRequest(2,3))
    proc2 = put!(channel(net, 2=>1), Tag(SwitchRequest(2,3)))
    proc3 = put!(messagebuffer(net[1]), Tag(SwitchRequest(2,3)))
    proc4 = put!(messagebuffer(net[1]), SwitchRequest(2,3))
    run(sim, 10)
    @test QuantumSavory.peektags(messagebuffer(net,1)) == [Tag(SwitchRequest(2,3)), Tag(SwitchRequest(2,3)), Tag(SwitchRequest(2,3)), Tag(SwitchRequest(2,3))]
    @test_throws "does not support `tag!`" tag!(messagebuffer(net, 1), EntanglementCounterpart, 1, 10)
end
