using Test, QuantumSavory, QuantumSavory.ProtocolZoo, CairoMakie
using ConcurrentSim, ResumableFunctions

@testset "ASPEN PNG timing history" begin
    net = RegisterNet([Register(2, QuantumOpticsRepr()) for _ in 1:3])
    schedule = AspenSchedule(heralding_prob=1, coincidence_prob=1)
    a = AspenSourceProt(net, 1, 2; schedule, central_fraction=1)
    b = AspenSourceProt(net, 3, 2; schedule, central_fraction=1)
    central = AspenCentralProt(net, 2, 1, 3; schedule)
    empty_images = [repr(MIME"image/png"(), prot) for prot in (a, central)]
    @process a()
    @process b()
    @process central()
    run(get_time_tracker(net), 1.0)
    for (prot, empty_image) in zip((a, central), empty_images)
        image = repr(MIME"image/png"(), prot)
        @test image[1:8] == empty_image[1:8] == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        @test image != empty_image
    end
end
