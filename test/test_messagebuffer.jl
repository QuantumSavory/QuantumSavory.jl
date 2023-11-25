using QuantumSavory
using QuantumSavory: tag_types
using ResumableFunctions, ConcurrentSim
using Test

net = RegisterNet([Register(3), Register(2), Register(3)])
env = get_time_tracker(net);
@resumable function receive_tags(env)
    while true
        mb = messagebuffer(net, 2)
        @yield wait(mb)
        msg = querypop!(mb, :second_tag, ❓, ❓)
        print("t=$(now(env)): query returns ")
        if isnothing(msg)
            #println("nothing")
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
