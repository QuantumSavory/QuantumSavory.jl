#=
# A basic example of two nodes sending the same qubit back and forth.

Let's set up two registers, one for Alice and one for Bob.
We will also create a network to connect them.
=#

using QuantumSavory

# Alice's register containing 1 qubit slot experiencing dephasing with ``T_2=``10 time units.
alice = Register(Qubit(), T2Dephasing(10))

# Bob's register containing 1 qubit slot, with no noise.
bob = Register(1)

# A network of two nodes, Alice and Bob (with default connection topology)
net = RegisterNet(
        [alice, bob]
    )

# A global clock used by the discrete event simulator
clock = get_time_tracker(net)

# Setting up simple channels from Alice to Bob and from Bob to Alice.
net[1=>2, :qchannel] = DelayQueue(clock, delay=10)
net[2=>1, :qchannel] = DelayQueue(clock, delay=10)

# What each node will be doing:
# - Waiting for a qubit to arrive on the channel
# - Storing it in the local Register
# - Waiting for a random amount of time (to simulate some processing and potential dephasing)
# - Measuring the qubit in the X basis, potentially observing a phase flip due to dephasing
# - Sending the qubit back on the channel

@resumable function node_protocol(clock, net, local_idx, remote_idx)
    while true:
        # receive the qubit
        qubit = @yield take!(net[remote_idx=>local_idx, :qchannel])
        @info "t=$(now(clock)) : node $(local_idx) received a qubit"

        # store the qubit in the local register
        initialize!(net[local_idx, 1], value(qubit))
        # wait between 0 and 1 time unit
        @yield timeout(clock, rand())

        # measure the qubit in the X basis
        meas = project_qnd!(net[local_idx, 1], X)
        @info "t=$(now(clock)) : node $(local_idx) measured a qubit in the X basis and observed $(meas)"

        take!()
        @info "t=$(now(clock)) : node $(local_idx) sent a qubit"
        put!(net[local_idx=>remote_idx, :qchannel], qubit)
    end
end
