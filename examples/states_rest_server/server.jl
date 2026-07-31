using Oxygen
using JSON3
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using QuantumSymbolics

const NO_QUERY_PARAMETERS = ()

function state_query_parameters(family, names)
    parameters = state_family_schema(family).parameters
    length(names) == length(parameters) ||
        throw(ArgumentError("REST aliases must match the state-family schema"))
    return Tuple(
        (String(name), Float64, Float64(parameter.recommended))
        for (name, parameter) in zip(names, parameters)
    )
end

const BARRETT_KOK_QUERY_PARAMETERS = (
    state_query_parameters(
        BarrettKokBellPair,
        ("etaA", "etaB", "Pd", "etad", "V"),
    )...,
    ("m", Int, 0),
    ("weighted", Bool, false),
)
const GENQO_ZALM_QUERY_PARAMETERS = state_query_parameters(
    GenqoMultiplexedCascadedBellPairW,
    ("etab", "etad", "etat", "N"),
)
const GENQO_SPDC_QUERY_PARAMETERS = state_query_parameters(
    GenqoUnheraldedSPDCBellPairW,
    ("etad", "etat", "N"),
)

function parameters_valid(family, values)
    schema = state_family_schema(family)
    return length(values) == length(schema.parameters) &&
           all(value in parameter for (value, parameter) in
               zip(values, schema.parameters))
end

parse_query_parameter(::Type{Bool}, value) =
    value == "true" ? true : value == "false" ? false :
    throw(ArgumentError("expected true or false"))
parse_query_parameter(type::Type, value) = parse(type, value)

function validated_queryparams(req, specifications)
    params = queryparams(req)
    allowed_parameters = first.(specifications)
    unknown_parameters = sort!(
        String[
            name
            for name in keys(params)
            if name ∉ allowed_parameters
        ],
    )
    if !isempty(unknown_parameters)
        return nothing, json(
            Dict(
                "error" => "Unknown query parameters",
                "unknown_parameters" => unknown_parameters,
            );
            status=400,
        )
    end

    values = Dict{String,Any}()
    for (name, type, default) in specifications
        raw_value = Base.get(params, name, string(default))
        values[name] = try
            parse_query_parameter(type, raw_value)
        catch
            return nothing, json(
                Dict(
                    "error" => "Invalid query parameter",
                    "parameter" => name,
                );
                status=400,
            )
        end
    end
    return values, nothing
end

@oxidize
@get "/api/health" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    return Dict("status" => "healthy", "message" => "QuantumSavory StatesZoo API is running -- see implementation details at https://github.com/QuantumSavory/QuantumSavory.jl/tree/main/examples/states_rest_server")
end

# Barrett-Kok Bell Pair endpoints
@get "/api/barrett-kok/density-matrix" function(req)
    params, rejection = validated_queryparams(req, BARRETT_KOK_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    ηᴬ = params["etaA"]
    ηᴮ = params["etaB"]
    Pᵈ = params["Pd"]
    ηᵈ = params["etad"]
    𝒱 = params["V"]
    m = params["m"]
    weighted = params["weighted"]

    try
        # Validate parameters
        values = (ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱)
        if !parameters_valid(BarrettKokBellPair, values) || m ∉ (0, 1)
            return json(
                Dict("error" => "Invalid parameters: values must satisfy the advertised state-family schema and m must be 0 or 1");
                status=400,
            )
        end

        # Create the state
        if weighted
            state = BarrettKokBellPairW(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m)
        else
            state = BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m)
        end

        # Get density matrix
        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => weighted ? "BarrettKokBellPairW" : "BarrettKokBellPair",
            "parameters" => Dict(
                "etaA" => ηᴬ,
                "etaB" => ηᴮ,
                "Pd" => Pᵈ,
                "etad" => ηᵈ,
                "V" => 𝒱,
                "m" => m
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(ρ)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return json(
            Dict("error" => "Failed to compute density matrix: $(string(e))");
            status=500,
        )
    end
end

@get "/api/barrett-kok/parameters" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    params = stateparameters(BarrettKokBellPair)
    ranges = stateparametersrange(BarrettKokBellPair)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etaA" => "Individual channel transmissivity from source A to entanglement swapping station, ∈(0,1]",
            "etaB" => "Individual channel transmissivity from source B to entanglement swapping station, ∈(0,1]",
            "Pd" => "Total excess noise (photons per qubit slot) in photon detectors, ∈[0,1), usually ≪1",
            "etad" => "Detection efficiency of photon detectors, ∈(0,1]",
            "V" => "Real-valued mode overlap used by the standard parameter sweep, ∈[0,1]",
            "m" => "Parity bit determined by click pattern (0 or 1)"
        )
    )
end

# Genqo ZALM (Multiplexed Cascaded) endpoints
@get "/api/genqo/zalm/density-matrix" function(req)
    params, rejection = validated_queryparams(req, GENQO_ZALM_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    ηᵇ = params["etab"]
    ηᵈ = params["etad"]
    ηᵗ = params["etat"]
    N = params["N"]

    try
        # Validate parameters
        if !parameters_valid(
            GenqoMultiplexedCascadedBellPairW,
            (ηᵇ, ηᵈ, ηᵗ, N),
        )
            return json(
                Dict("error" => "Invalid parameters: values must satisfy the advertised state-family schema");
                status=400,
            )
        end

        # Create the state
        state = GenqoMultiplexedCascadedBellPairW(ηᵇ, ηᵈ, ηᵗ, N)

        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => "GenqoMultiplexedCascadedBellPairW",
            "parameters" => Dict(
                "etab" => ηᵇ,
                "etad" => ηᵈ,
                "etat" => ηᵗ,
                "N" => N
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(ρ)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return json(
            Dict("error" => "Failed to compute density matrix: $(string(e))");
            status=500,
        )
    end
end

@get "/api/genqo/zalm/parameters" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    params = stateparameters(GenqoMultiplexedCascadedBellPairW)
    ranges = stateparametersrange(GenqoMultiplexedCascadedBellPairW)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etab" => "Loss (transmissivity) in the Bell state measurement at the source, ∈(0,1]",
            "etad" => "Loss (transmissivity) in all of the detectors, ∈(0,1]",
            "etat" => "Outcoupling transmissivity for the bell-state modes, ∈(0,1]",
            "N" => "Mean photon number per mode of the state (tradeoff for fidelity vs rate), >0"
        )
    )
end

# Genqo SPDC endpoints
@get "/api/genqo/spdc/density-matrix" function(req)
    params, rejection = validated_queryparams(req, GENQO_SPDC_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    ηᵈ = params["etad"]
    ηᵗ = params["etat"]
    N = params["N"]

    try
        # Validate parameters
        if !parameters_valid(GenqoUnheraldedSPDCBellPairW, (ηᵈ, ηᵗ, N))
            return json(
                Dict("error" => "Invalid parameters: values must satisfy the advertised state-family schema");
                status=400,
            )
        end

        # Create the state
        state = GenqoUnheraldedSPDCBellPairW(ηᵈ, ηᵗ, N)

        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => "GenqoUnheraldedSPDCBellPairW",
            "parameters" => Dict(
                "etad" => ηᵈ,
                "etat" => ηᵗ,
                "N" => N
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(density_matrix)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return json(
            Dict("error" => "Failed to compute density matrix: $(string(e))");
            status=500,
        )
    end
end

@get "/api/genqo/spdc/parameters" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    params = stateparameters(GenqoUnheraldedSPDCBellPairW)
    ranges = stateparametersrange(GenqoUnheraldedSPDCBellPairW)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etad" => "Loss (transmissivity) in all of the detectors, ∈(0,1]",
            "etat" => "Outcoupling transmissivity for the bell-state modes, ∈(0,1]",
            "N" => "Mean photon number per mode of the state (tradeoff for fidelity vs rate), >0"
        )
    )
end

# General info endpoint
@get "/api/states" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    return Dict(
        "available_states" => [
            Dict(
                "name" => "BarrettKokBellPair",
                "description" => "Normalized Barrett-Kok Bell pair state",
                "endpoint" => "/api/barrett-kok/density-matrix",
                "parameters_endpoint" => "/api/barrett-kok/parameters"
            ),
            Dict(
                "name" => "BarrettKokBellPairW",
                "description" => "Weighted Barrett-Kok Bell pair state (trace = success probability)",
                "endpoint" => "/api/barrett-kok/density-matrix?weighted=true",
                "parameters_endpoint" => "/api/barrett-kok/parameters"
            ),
            Dict(
                "name" => "GenqoMultiplexedCascadedBellPairW",
                "description" => "Heralded multiplexed cascaded source (ZALM)",
                "endpoint" => "/api/genqo/zalm/density-matrix",
                "parameters_endpoint" => "/api/genqo/zalm/parameters"
            ),
            Dict(
                "name" => "GenqoUnheraldedSPDCBellPairW",
                "description" => "Unheralded SPDC Bell pair source",
                "endpoint" => "/api/genqo/spdc/density-matrix",
                "parameters_endpoint" => "/api/genqo/spdc/parameters"
            )
        ]
    )
end

# Start the server
if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting QuantumSavory StatesZoo API server...")
    println("Available endpoints:")
    println("  GET /api/health - Health check")
    println("  GET /api/states - List available quantum states")
    println("  GET /api/barrett-kok/density-matrix - Barrett-Kok Bell pair density matrix")
    println("  GET /api/barrett-kok/parameters - Barrett-Kok parameters info")
    println("  GET /api/genqo/zalm/density-matrix - Genqo ZALM density matrix")
    println("  GET /api/genqo/zalm/parameters - Genqo ZALM parameters info")
    println("  GET /api/genqo/spdc/density-matrix - Genqo SPDC density matrix")
    println("  GET /api/genqo/spdc/parameters - Genqo SPDC parameters info")

    port = parse(Int, Base.get(ENV, "QS_STATES_REST_SERVER_PORT", "8080"))
    host = Base.get(ENV, "QS_STATES_REST_SERVER_IP", "127.0.0.1")
    external_url = Base.get(ENV, "QS_STATES_REST_SERVER_PROXY", nothing)
    docs_path = Base.get(ENV, "QS_STATES_REST_SERVER_DOCPATH", "/docs")
    serve(;port, host, external_url, docs_path)
end
