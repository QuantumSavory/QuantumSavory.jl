using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using CairoMakie
CairoMakie.activate!()

png_bytes(x) = (io = IOBuffer(); show(io, MIME"image/png"(), x); take!(io))
is_valid_png(b) = length(b) > 1000 && b[1:8] == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

@testset "qTCP protocol PNG show" begin
    net = RegisterNet([Register(5) for _ in 1:3]; names=["n1", "n2", "n3"])
    sim = get_time_tracker(net)

    mb1 = messagebuffer(net, 1)
    put!(mb1, Flow(src=1, dst=3, npairs=2, uuid=42))
    put!(mb1, QDatagram(flow_uuid=42, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))

    for prot in (EndNodeController(sim, net, 1), NetworkNodeController(sim, net, 2), LinkController(sim, net, 1, 2))
        @test is_valid_png(png_bytes(prot))
    end
end
