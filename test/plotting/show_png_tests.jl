using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using CairoMakie
import InteractiveUtils, REPL

@testset "show image/png" begin

#out = stdout
out = IOBuffer()

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

#show(out, MIME"image/png"(), reg[1])
#show(out, MIME"image/png"(), reg[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg[1]))

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2]; name="my net", names=["reg 1", "reg 2"])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


prot = EntanglerProt(get_time_tracker(net), net, 1, 2)
show(out, MIME"image/png"(), prot)

qtcp_net = RegisterNet(
    [Register(3), Register(3), Register(3)];
    name="qtcp-line",
    names=["source", "repeater", "sink"],
)
qtcp_sim = get_time_tracker(qtcp_net)

put!(qtcp_net[1], Flow(src=1, dst=3, npairs=2, uuid=7))
put!(qtcp_net[1], QTCPPairBegin(flow_uuid=7, flow_src=1, flow_dst=3, seq_num=1, memory_slot=1, start_time=0.0))
put!(qtcp_net[2], QDatagram(flow_uuid=7, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))
put!(qtcp_net[1], LinkLevelRequest(flow_uuid=7, seq_num=1, remote_node=2))

for prot in (
    EndNodeController(qtcp_sim, qtcp_net, 1),
    NetworkNodeController(qtcp_sim, qtcp_net, 2),
    LinkController(qtcp_sim, qtcp_net, 1, 2),
)
    old_position = position(out)
    show(out, MIME"image/png"(), prot)
    @test position(out) > old_position
end

end
