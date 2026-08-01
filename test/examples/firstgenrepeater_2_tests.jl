using Test

@testset "Examples - firstgenrepeater 2" begin
    try
        include("../../examples/firstgenrepeater/2_swapper_example.jl")
        parameter_schemas = state_family_schema(BarrettKokBellPair).parameters
        state_config = Dict{Symbol,Any}(
            parameter.name => parameter.recommended
            for parameter in parameter_schemas
        )
        even_pair = barrett_kok_pair(state_config)
        state_config[:m] = 1
        odd_pair = barrett_kok_pair(state_config)
        @test express(even_pair).data != express(odd_pair).data
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
