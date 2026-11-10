using Test
using QuantumSavory, Graphs, CairoMakie
using QuantumSavory.ProtocolZoo.AspenNet: Source, LocalMeasurement, Hub

@testset "AspenNet displays" begin
    net = RegisterNet(path_graph(3), [Register(fill(Qumode(), n), fill(QuantumOpticsRepr(cutoff=4), n)) for n in (1, 2, 1)])
    source = Source(net, 1, 2)
    measurement = LocalMeasurement(net, 1)
    hub = Hub(net, 2, (1, 3))
    signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    for protocol in (source, measurement, hub)
        @test first(repr(MIME"image/png"(), protocol), 8) == signature
        @test occursin("AspenNet", repr(MIME"text/plain"(), protocol))
        @test occursin("quantumsavory_protocol_aspennet", repr(MIME"text/html"(), protocol))
    end
    for protocol in (measurement, hub)
        empty_png = repr(MIME"image/png"(), protocol)
        history = Observable(copy(protocol._log))
        extension = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
        axis = extension.protshowimage(Figure()[1, 1], protocol; history)
        points, empty_message = axis.scene.plots
        @test isempty(points[1][])
        @test empty_message.visible[]
        entry = protocol === hub ? (t=3.0, period=1, success=true) : (t=1.0, period=1, slot=1, number=1)
        push!(protocol._log, entry)
        history[] = copy(protocol._log)
        @test points[1][] == [Point2f(entry.t, 1)]
        @test !empty_message.visible[]
        empty!(history[])
        notify(history)
        @test isempty(points[1][])
        @test empty_message.visible[]
        populated_png = repr(MIME"image/png"(), protocol)
        @test first(populated_png, 8) == signature
        @test populated_png != empty_png
    end
end
