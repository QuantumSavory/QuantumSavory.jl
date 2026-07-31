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

    for (path, parameter) in (
        ("/api/barrett-kok/density-matrix?etaA=not-a-number", "etaA"),
        ("/api/barrett-kok/density-matrix?m=not-an-integer", "m"),
        ("/api/barrett-kok/density-matrix?weighted=yes", "weighted"),
        ("/api/genqo/zalm/density-matrix?N=not-a-number", "N"),
        ("/api/genqo/spdc/density-matrix?N=not-a-number", "N"),
    )
        response = request(path)
        body = response_body(response)
        @test response.status == 400
        @test body.error == "Invalid query parameter"
        @test body.parameter == parameter
    end

    for path in (
        "/api/barrett-kok/density-matrix?etaA=0",
        "/api/barrett-kok/density-matrix?m=2",
        "/api/genqo/zalm/density-matrix?N=0",
        "/api/genqo/spdc/density-matrix?N=0",
    )
        response = request(path)
        @test response.status == 400
        @test startswith(
            response_body(response).error,
            "Invalid parameters:",
        )
    end

    @test request("/api/health").status == 200
    @test request("/api/barrett-kok/density-matrix?etaA=0.9").status == 200
    @test request("/api/barrett-kok/density-matrix?weighted=false").status == 200
    @test request("/api/barrett-kok/density-matrix?weighted=true").status == 200
    @test request("/api/genqo/zalm/density-matrix?N=0.1").status == 200
    @test request("/api/genqo/spdc/density-matrix?N=0.1").status == 200
end
