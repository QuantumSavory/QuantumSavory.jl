using Oxygen
using JSON3
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW,
    GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using QuantumSymbolics

const NO_QUERY_PARAMETERS = ()
const SOURCE_URL = string(
    "https://github.com/QuantumSavory/QuantumSavory.jl/tree/main/",
    "examples/states_rest_server",
)

"""REST routing metadata layered over one simulator-owned state schema."""
struct RestStateSpec
    family::Type
    slug::String
    parameter_aliases::Tuple{Vararg{Pair{Symbol,String}}}

    function RestStateSpec(
        family::Type,
        slug::AbstractString,
        parameter_aliases::Tuple{Vararg{Pair{Symbol,String}}},
    )
        schema = state_family_schema(family)
        simulator_names = map(parameter -> parameter.name, schema.parameters)
        first.(parameter_aliases) == simulator_names || throw(ArgumentError(
            "REST parameter mappings must match the ordered state-family schema",
        ))
        aliases = last.(parameter_aliases)
        all(alias -> !isempty(alias) && isascii(alias), aliases) ||
            throw(ArgumentError("REST aliases must be nonempty ASCII strings"))
        allunique(aliases) ||
            throw(ArgumentError("REST aliases must be unique"))
        isempty(slug) && throw(ArgumentError("REST state slug cannot be empty"))
        return new(family, String(slug), parameter_aliases)
    end
end

const STATE_REST_SPECS = (
    RestStateSpec(
        BarrettKokBellPair,
        "barrett-kok",
        (
            :ηᴬ => "etaA",
            :ηᴮ => "etaB",
            :Pᵈ => "Pd",
            :ηᵈ => "etad",
            :𝒱 => "V",
            :m => "m",
        ),
    ),
    RestStateSpec(
        BarrettKokBellPairW,
        "barrett-kok-weighted",
        (
            :ηᴬ => "etaA",
            :ηᴮ => "etaB",
            :Pᵈ => "Pd",
            :ηᵈ => "etad",
            :𝒱 => "V",
            :m => "m",
        ),
    ),
    RestStateSpec(DepolarizedBellPair, "depolarized", (:p => "p",)),
    RestStateSpec(
        GenqoMultiplexedCascadedBellPairW,
        "genqo/zalm",
        (:ηᵇ => "etab", :ηᵈ => "etad", :ηᵗ => "etat", :N => "N"),
    ),
    RestStateSpec(
        GenqoUnheraldedSPDCBellPairW,
        "genqo/spdc",
        (:ηᵈ => "etad", :ηᵗ => "etat", :N => "N"),
    ),
)

map(spec -> spec.family, STATE_REST_SPECS) ==
    map(schema -> schema.family, state_family_schemas()) ||
    error("the REST registry must cover every built-in state-family schema")

density_endpoint(spec::RestStateSpec) =
    "/api/$(spec.slug)/density-matrix"
parameters_endpoint(spec::RestStateSpec) =
    "/api/$(spec.slug)/parameters"
parameter_aliases(spec::RestStateSpec) = last.(spec.parameter_aliases)

query_value_type(parameter::StateParameterSchema) =
    parameter.value_type <: Integer ? Int : Float64

function state_query_parameters(spec::RestStateSpec)
    schema = state_family_schema(spec.family)
    return Tuple(
        (
            alias,
            query_value_type(parameter),
            convert(query_value_type(parameter), parameter.recommended),
        )
        for (alias, parameter) in zip(parameter_aliases(spec), schema.parameters)
    )
end

function parameters_valid(spec::RestStateSpec, values)
    parameters = state_family_schema(spec.family).parameters
    return length(values) == length(parameters) &&
           all(value in parameter for (value, parameter) in
               zip(values, parameters))
end

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

normalization_name(style::StateNormalizationStyle) =
    style === NormalizedState ? "normalized" : "weighted"

function parameter_record(alias, parameter::StateParameterSchema)
    return Dict(
        "name" => alias,
        "simulator_name" => String(parameter.name),
        "type" => parameter.value_type <: Integer ? "integer" : "number",
        "description" => parameter.doc,
        "minimum" => parameter.minimum,
        "maximum" => parameter.maximum,
        "minimum_inclusive" => parameter.minimum_inclusive,
        "maximum_inclusive" => parameter.maximum_inclusive,
        "default" => parameter.recommended,
    )
end

function parameters_response(req, spec::RestStateSpec)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    schema = state_family_schema(spec.family)
    return Dict(
        "state_type" => String(nameof(spec.family)),
        "normalization" => normalization_name(schema.normalization),
        "parameters" => [
            parameter_record(alias, parameter)
            for (alias, parameter) in
                zip(parameter_aliases(spec), schema.parameters)
        ],
    )
end

function density_matrix_response(req, spec::RestStateSpec)
    params, rejection = validated_queryparams(req, state_query_parameters(spec))
    isnothing(rejection) || return rejection

    aliases = parameter_aliases(spec)
    values = Tuple(params[alias] for alias in aliases)
    if !parameters_valid(spec, values)
        return json(
            Dict(
                "error" => string(
                    "Invalid parameters: values must satisfy the ",
                    "advertised state-family schema",
                ),
            );
            status=400,
        )
    end

    try
        state = spec.family(values...)
        density_operator = express(state, QuantumOpticsRepr())
        density_matrix = Array(density_operator.data)
        return Dict(
            "state_type" => String(nameof(spec.family)),
            "parameters" => Dict(zip(aliases, values)),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix),
            ),
            "trace" => real(tr(density_operator)),
            "dimensions" => size(density_matrix),
        )
    catch error
        return json(
            Dict(
                "error" => "Failed to compute density matrix: $(string(error))",
            );
            status=500,
        )
    end
end

function states_response(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    return Dict(
        "available_states" => [
            let schema = state_family_schema(spec.family)
                Dict(
                    "name" => String(nameof(spec.family)),
                    "description" => schema.doc,
                    "normalization" => normalization_name(schema.normalization),
                    "endpoint" => density_endpoint(spec),
                    "parameters_endpoint" => parameters_endpoint(spec),
                )
            end
            for spec in STATE_REST_SPECS
        ],
    )
end

@oxidize

@get "/api/health" function(req)
    _, rejection = validated_queryparams(req, NO_QUERY_PARAMETERS)
    isnothing(rejection) || return rejection

    return Dict(
        "status" => "healthy",
        "message" => string(
            "QuantumSavory StatesZoo API is running -- ",
            "see implementation details at ",
            SOURCE_URL,
        ),
    )
end

@get "/api/states" function(req)
    return states_response(req)
end

@get "/api/barrett-kok/density-matrix" function(req)
    return density_matrix_response(req, STATE_REST_SPECS[1])
end
@get "/api/barrett-kok/parameters" function(req)
    return parameters_response(req, STATE_REST_SPECS[1])
end

@get "/api/barrett-kok-weighted/density-matrix" function(req)
    return density_matrix_response(req, STATE_REST_SPECS[2])
end
@get "/api/barrett-kok-weighted/parameters" function(req)
    return parameters_response(req, STATE_REST_SPECS[2])
end

@get "/api/depolarized/density-matrix" function(req)
    return density_matrix_response(req, STATE_REST_SPECS[3])
end
@get "/api/depolarized/parameters" function(req)
    return parameters_response(req, STATE_REST_SPECS[3])
end

@get "/api/genqo/zalm/density-matrix" function(req)
    return density_matrix_response(req, STATE_REST_SPECS[4])
end
@get "/api/genqo/zalm/parameters" function(req)
    return parameters_response(req, STATE_REST_SPECS[4])
end

@get "/api/genqo/spdc/density-matrix" function(req)
    return density_matrix_response(req, STATE_REST_SPECS[5])
end
@get "/api/genqo/spdc/parameters" function(req)
    return parameters_response(req, STATE_REST_SPECS[5])
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting QuantumSavory StatesZoo API server...")
    println("Available endpoints:")
    println("  GET /api/health - Health check")
    println("  GET /api/states - List available quantum states")
    for spec in STATE_REST_SPECS
        println("  GET $(density_endpoint(spec)) - Density matrix")
        println("  GET $(parameters_endpoint(spec)) - Parameter schema")
    end

    port = parse(Int, Base.get(ENV, "QS_STATES_REST_SERVER_PORT", "8080"))
    host = Base.get(ENV, "QS_STATES_REST_SERVER_IP", "127.0.0.1")
    external_url = Base.get(ENV, "QS_STATES_REST_SERVER_PROXY", nothing)
    docs_path = Base.get(ENV, "QS_STATES_REST_SERVER_DOCPATH", "/docs")
    serve(;port, host, external_url, docs_path)
end
