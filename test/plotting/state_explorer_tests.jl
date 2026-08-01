using Test
using QuantumSavory
using QuantumSavory.StatesZoo: BarrettKokBellPairW, stateexplorer
using CairoMakie

CairoMakie.activate!()

@testset "StatesZoo explorer uses family parameter metadata" begin
    extension_module = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    @test !isnothing(extension_module)

    slider_specs = extension_module._state_parameter_slider_specs(
        BarrettKokBellPairW,
    )

    @test length(slider_specs) == 6
    @test map(spec -> spec.name, slider_specs) ==
        (:ηᴬ, :ηᴮ, :Pᵈ, :ηᵈ, :𝒱, :m)
    @test map(spec -> spec.recommended, slider_specs) ==
        (1.0, 1.0, 0.0, 1.0, 1.0, 0)
    @test all(slider_specs[1:5]) do spec
        spec.range isa AbstractRange{Float64} && length(spec.range) == 30
    end
    @test slider_specs[6].range == [0, 1]

    figure = stateexplorer(BarrettKokBellPairW)

    @test figure isa Figure
end
