using Test
using JSON3
using Oxygen
using QuantumSavory.StatesZoo

include("../../examples/states_rest_server/server.jl")

request(path) = internalrequest(Request("GET", path))
response_body(response) = JSON3.read(String(response.body))

@testset "StatesZoo REST query contract" begin
    routes = (
        "/api/health",
        "/api/states",
        (density_endpoint(spec) for spec in STATE_REST_SPECS)...,
        (parameters_endpoint(spec) for spec in STATE_REST_SPECS)...,
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

    for (path, parameter) in (
        ("/api/barrett-kok/density-matrix?etaA=not-a-number", "etaA"),
        ("/api/barrett-kok/density-matrix?m=0.5", "m"),
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
        "/api/depolarized/density-matrix?p=2",
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

    response = request("/api/barrett-kok/density-matrix?weighted=true")
    @test response.status == 400
    @test collect(response_body(response).unknown_parameters) == ["weighted"]

    @test request("/api/health").status == 200
    for spec in STATE_REST_SPECS
        @test request(density_endpoint(spec)).status == 200
        @test request(parameters_endpoint(spec)).status == 200
    end
    @test request("/api/barrett-kok/density-matrix?m=1").status == 200
end

@testset "StatesZoo REST discovery is schema-derived" begin
    @test_throws ArgumentError RestStateSpec(
        DepolarizedBellPair,
        "invalid",
        (:wrong => "p",),
    )
    catalog_response = request("/api/states")
    @test catalog_response.status == 200
    states = collect(response_body(catalog_response).available_states)
    schemas = state_family_schemas()

    @test String[state.name for state in states] ==
          String[String(nameof(schema.family)) for schema in schemas]
    @test String[state.normalization for state in states] ==
          String[
              schema.normalization === NormalizedState ?
                  "normalized" : "weighted"
              for schema in schemas
          ]
    @test String[state.endpoint for state in states] ==
          String[density_endpoint(spec) for spec in STATE_REST_SPECS]
    @test String[state.parameters_endpoint for state in states] ==
          String[parameters_endpoint(spec) for spec in STATE_REST_SPECS]
    @test "DepolarizedBellPair" in String[state.name for state in states]

    for (spec, schema) in zip(STATE_REST_SPECS, schemas)
        response = request(parameters_endpoint(spec))
        @test response.status == 200
        body = response_body(response)
        parameters = collect(body.parameters)

        @test body.state_type == String(nameof(schema.family))
        @test body.normalization ==
              (schema.normalization === NormalizedState ?
               "normalized" : "weighted")
        @test String[parameter.name for parameter in parameters] ==
              collect(parameter_aliases(spec))
        @test String[parameter.simulator_name for parameter in parameters] ==
              String[String(parameter.name) for parameter in schema.parameters]

        for (record, parameter) in zip(parameters, schema.parameters)
            @test record.type ==
                  (parameter.value_type <: Integer ? "integer" : "number")
            @test record.description == parameter.doc
            @test record.minimum == parameter.minimum
            @test record.maximum == parameter.maximum
            @test record.minimum_inclusive == parameter.minimum_inclusive
            @test record.maximum_inclusive == parameter.maximum_inclusive
            @test record.default == parameter.recommended
        end

        density = response_body(request(density_endpoint(spec)))
        @test density.state_type == String(nameof(schema.family))
        @test sort!(String.(collect(keys(density.parameters)))) ==
              sort!(collect(parameter_aliases(spec)))
        @test density.dimensions == [4, 4]
    end
end
