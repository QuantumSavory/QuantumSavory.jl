include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!()


# Configuration variables
PURIFICATION = true                 # if true, purification is also performed
console = false                     # if true, the program will not produce a vide file
time = 20.3                         # time to run the simulation
commtimes = [0.1, 0.1]            # communication times from sender->receiver, and receiver->sender
registersizes = [6, 6]               # sizes of the registers
node_timedelay = [0.4, 0.3]         # waittime and busytime for processes
noisy_pair = noisy_pair_func(0.7)   # noisy pair
USE = 3                             # 3 for double selection, 2 for single selection

purifcircuit = Dict(
    2=>purify2to1,
    3=>purify3to1
)

protocol = FreeQubitTriggerProtocolSimulation(USE, purifcircuit[USE], # purifcircuit
                                                node_timedelay[1], node_timedelay[2], # wait and busy times
                                                Dict(:simple_channel=>:yayayayya,
                                                    :process_channel=>:yoyoyooy), # keywords to store the 2 types of channels in the network
                                                false, 10) # recicle purified pairs
                                                
sim, network = simulation_setup(registersizes, commtimes, protocol) # Simulation and Network

# Setting up the ENTANGMELENT protocol
for (;src, dst) in edges(network)
    @process freequbit_trigger(sim, protocol, network, src, dst)
    @process entangle(sim, protocol, network, src, dst)
    @process entangle(sim, protocol, network, dst, src)
end
# Setting up the purification protocol 
if PURIFICATION
    for (;src, dst) in edges(network)
        @process purifier(sim, protocol, network, src, dst)
        @process purifier(sim, protocol, network, dst, src)
    end
end

bell = StabilizerState("XX ZZ")
# Running the simulation
if console
    run(sim, time)
else
    # set up a plot and save a handle to the plot observable
    fig = Figure(resolution=(400,400))
    _,ax,_,obs = registernetplot_axis(fig[1,1],network; twoqubitobservable=projector(bell))
    display(fig)

    # record the simulation progress
    step_ts = range(0, time, step=0.1)
    record(fig, "1_firstgenrepeater_$(length(registersizes))nodes.$(PURIFICATION ? "entpurif$(USE)to1" : "entonly").mp4", step_ts, framerate=10, visible=true) do t
        run(sim, t)
        notify(obs)
        ax.title = "t=$(t)"
    end
end
