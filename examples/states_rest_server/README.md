# QuantumSavory StatesZoo REST API

This example exposes every built-in `StatesZoo` family through a small Oxygen
REST API. Its state list, ASCII query names, defaults, numeric types, bounds,
normalization styles, and parameter documentation come from one validated
registry layered over `state_family_schemas()`.

## Run It

From this directory:

```bash
julia --project=. server.jl
```

The default base URL is `http://127.0.0.1:8080`. Oxygen serves generated
interactive API documentation at `/docs`; set
`QS_STATES_REST_SERVER_DOCPATH` to change that path.

## Discover The Contract

- `GET /api/health` reports service health.
- `GET /api/states` lists every available family and its two endpoints.
- `GET /api/<state>/parameters` returns the exact ordered query schema.
- `GET /api/<state>/density-matrix` evaluates the family.

The current state slugs are:

- `barrett-kok`
- `barrett-kok-weighted`
- `depolarized`
- `genqo/zalm`
- `genqo/spdc`

For example:

```bash
curl http://127.0.0.1:8080/api/states
curl http://127.0.0.1:8080/api/barrett-kok/parameters
curl 'http://127.0.0.1:8080/api/barrett-kok/density-matrix?etaA=0.9&m=1'
curl http://127.0.0.1:8080/api/barrett-kok-weighted/density-matrix
curl 'http://127.0.0.1:8080/api/depolarized/density-matrix?p=0.95'
```

Each parameter record has this shape:

```json
{
  "name": "etaA",
  "simulator_name": "ηᴬ",
  "type": "number",
  "description": "Channel transmissivity from source A to the swapping station.",
  "minimum": 0,
  "maximum": 1,
  "minimum_inclusive": false,
  "maximum_inclusive": true,
  "default": 1
}
```

`name` is the ASCII query key. `simulator_name` identifies the corresponding
`StateParameterSchema`; clients do not send it.

## Density-Matrix Response

```json
{
  "state_type": "DepolarizedBellPair",
  "parameters": {"p": 0.95},
  "density_matrix": {
    "real": [[0.4875, 0, 0, 0.475], [0, 0.0125, 0, 0], [0, 0, 0.0125, 0], [0.475, 0, 0, 0.4875]],
    "imag": [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
  },
  "trace": 1,
  "dimensions": [4, 4]
}
```

Weighted families have a trace that carries their success weight. The server
does not silently normalize them.

## Validation

Every route has a closed query schema. Unknown keys, values that cannot be
parsed as the advertised numeric type, and values outside the exact simulator
bounds return HTTP 400. For example:

```json
{
  "error": "Unknown query parameters",
  "unknown_parameters": ["weighted"]
}
```

Normalized and weighted Barrett–Kok states use distinct endpoints; the old
`weighted` Boolean switch is intentionally not accepted.

Environment variables can override the listener:

- `QS_STATES_REST_SERVER_PORT` (default `8080`)
- `QS_STATES_REST_SERVER_IP` (default `127.0.0.1`)
- `QS_STATES_REST_SERVER_PROXY`
- `QS_STATES_REST_SERVER_DOCPATH` (default `/docs`)
