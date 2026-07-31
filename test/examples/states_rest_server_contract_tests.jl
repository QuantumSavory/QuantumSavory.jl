using Test
using JSON3
using Oxygen

include("../../examples/states_rest_server/server.jl")

request(path) = internalrequest(Request("GET", path))
response_body(response) = JSON3.read(String(response.body))

@testset "StatesZoo REST query contract" begin
    routes = (
        "/api/health",
        "/api/barrett-kok/density-matrix",
        "/api/barrett-kok/parameters",
        "/api/genqo/zalm/density-matrix",
        "/api/genqo/zalm/parameters",
        "/api/genqo/spdc/density-matrix",
        "/api/genqo/spdc/parameters",
        "/api/states",
    )

    for route in routes
        response = request("$route?unexpected=true")
        body = response_body(response)
        @test response.status == 400
        @test body.error == "Unknown query parameters"
        @test collect(body.unknown_parameters) == ["unexpected"]
    end

    response = request("/api/health?z=true&a=true")
    @test response.status == 400
    @test collect(response_body(response).unknown_parameters) == ["a", "z"]

    for route in (
        "/api/genqo/zalm/density-matrix",
        "/api/genqo/spdc/density-matrix",
    )
        response = request("$route?Pd=0.1")
        body = response_body(response)
        @test response.status == 400
        @test body.error == "Unknown query parameters"
        @test collect(body.unknown_parameters) == ["Pd"]
    end

    @test request("/api/health").status == 200
    @test request("/api/barrett-kok/density-matrix?etaA=0.9").status == 200
    @test request("/api/genqo/zalm/density-matrix?N=0.1").status == 200
    @test request("/api/genqo/spdc/density-matrix?N=0.1").status == 200
end
