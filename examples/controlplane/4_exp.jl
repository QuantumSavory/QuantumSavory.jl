using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions

using Graphs
using GLMakie
GLMakie.activate!()

using NetworkLayout
using Random

adjm = [0 1 0 0 1 0 0 0
        1 0 1 0 0 0 0 0
        0 1 0 1 0 1 0 0
        0 0 1 0 0 0 1 1
        1 0 0 0 0 1 0 1
        0 0 1 0 1 0 1 0
        0 0 0 1 0 1 0 1
        0 0 0 1 1 0 1 0]
graph = SimpleGraph(adjm)

regsize = 20


net = RegisterNet(graph, [Register(regsize, T1Decay(10.0)) for i in 1:8])
sim = get_time_tracker(net)


controller = Controller(sim, net, 6, zeros(8,8))
@process controller()

req_gen = RequestGeneratorCO(sim, net, 1, 8, 6)
@process req_gen()

for node in 1:7
    tracker = RequestTracker(sim, net, node)
    @process tracker()
end

for v in 1:8
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

for v in 1:8
    c_prot = CutoffProt(sim, net, v)
    @process c_prot()
end

consumerCO = EntanglementConsumer(sim, net, 1, 8)
@process consumerCO()

run(sim, 500)
######################################

net = RegisterNet(graph, [Register(regsize, T1Decay(10.0)) for i in 1:8])
sim = get_time_tracker(net)


for (;src, dst) in edges(net)
    entangler = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true)
    @process entangler()
end

controller = CLController(sim, net, 6)
@process controller()

req_gen = RequestGeneratorCL(sim, net, 1, 8, 6)
@process req_gen()

for node in 1:7
    tracker = RequestTracker(sim, net, node)
    @process tracker()
end

for v in 1:8
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

for v in 1:8
    c_prot = CutoffProt(sim, net, v)
    @process c_prot()
end

consumerCL = EntanglementConsumer(sim, net, 1, 8)
@process consumerCL()

run(sim, 500)

####return 3 metrics: Time to success, Time evolution of average fidelity, avg number of pairs per unit time
function metrics(consumer)
    entlog = consumer.log
    ts = [e[1] for e in entlog]
    txxs = [Point2f(e[1],e[3]) for e in entlog]
    Δts = length(ts)>1 ? ts[2:end] .- ts[1:end-1] : [0.0] #Times to success

    ###
    avg_fids = cumsum([e[3] for e in entlog])./cumsum(ones(length(entlog))) #avg fidelity per unit time
    fid_info = [Point2f(t,f) for (t,f) in zip(ts, avg_fids)]

    ##
    num_epr = cumsum(ones(length(entlog)))./(ts) #avg number of pairs per unit time
    num_epr_info = [Point2f(t,n) for (t,n) in zip(ts, num_epr)]

    return Δts, fid_info, num_epr_info
end

Δts_co, fid_co, num_epr_co = metrics(consumerCO)
Δts_cl, fid_cl, num_epr_cl = metrics(consumerCL)


fig = Figure(;size=(1200, 1500))

histaxis1 = Axis(fig[1,1], xlabel="ΔTime", title="Histogram of Time to Successes(Connection-Oriented)")
hist!(histaxis1, Δts_co)

histaxis2 = Axis(fig[1,2], xlabel="ΔTime", title="Histogram of Time to Successes(Connection-Less)")
hist!(histaxis2, Δts_cl)

fid_axis1 = Axis(fig[2,1], xlabel="Time", ylabel="Avg. Fidelity", title="Time evolution of Average Fidelity")
ylims!(fid_axis1, (0.0, 1.0))
lines!(fid_axis1, fid_co)

fid_axis2 = Axis(fig[2,2], xlabel="Time", ylabel="Avg. Fidelity", title="Time evolution of Average Fidelity")
ylims!(fid_axis2, (0.0, 1.0))
lines!(fid_axis2, fid_cl)

num_epr_axis1 = Axis(fig[3,1], xlabel="Time", title="Avg. Number of Entangled Pairs between Alice and Bob")
lines!(num_epr_axis1, num_epr_co)

num_epr_axis2 = Axis(fig[3,2], xlabel="Time", title="Avg. Number of Entangled Pairs between Alice and Bob")
lines!(num_epr_axis2, num_epr_cl)

display(fig)
save("fig.png", fig)