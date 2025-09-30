# QuantumSavory StatesZoo REST API

This REST API provides access to density matrices from quantum states in the QuantumSavory StatesZoo, including Barrett-Kok Bell pairs and states from the Genqo package.

## Quick Start

### Prerequisites

1. Julia 1.11+ with QuantumSavory.jl installed
2. Oxygen.jl for the REST API framework
3. JSON3.jl for JSON handling

### Running the Server

From the folder containing the server and the Project.toml file with the dependencies:

```bash
julia --project=. api_server.jl
```

The server will start on `http://localhost:8080`

## API Endpoints

### Health Check
- **GET** `/api/health`
- Returns server status

### Available States
- **GET** `/api/states`
- Lists all available quantum state types with their endpoints

### Barrett-Kok Bell Pairs

#### Get Density Matrix
- **GET** `/api/barrett-kok/density-matrix`
- **Parameters:**
  - `etaA` (optional): Transmissivity from source A, ∈[0,1], default=1.0
  - `etaB` (optional): Transmissivity from source B, ∈[0,1], default=1.0
  - `Pd` (optional): Excess noise in detectors, ≥0, default=0.0
  - `etad` (optional): Detection efficiency, ∈[0,1], default=1.0
  - `V` (optional): Mode matching parameter, |V|∈[0,1], default=1.0
  - `m` (optional): Parity bit (0 or 1), default=0
  - `weighted` (optional): Return weighted version (trace = success probability), default=false

#### Get Parameters Info
- **GET** `/api/barrett-kok/parameters`
- Returns parameter descriptions and valid ranges

### Genqo ZALM (Multiplexed Cascaded Source)

#### Get Density Matrix
- **GET** `/api/genqo/zalm/density-matrix`
- **Parameters:**
  - `etab` (optional): BSM transmissivity, ∈[0,1], default=1.0
  - `etad` (optional): Detector transmissivity, ∈[0,1], default=1.0
  - `etat` (optional): Outcoupling transmissivity, ∈[0,1], default=1.0
  - `N` (optional): Mean photon number, >0, default=0.1
  - `Pd` (optional): Excess noise, ≥0, default=1e-8

#### Get Parameters Info
- **GET** `/api/genqo/zalm/parameters`
- Returns parameter descriptions and valid ranges

### Genqo SPDC (Unheralded Source)

#### Get Density Matrix
- **GET** `/api/genqo/spdc/density-matrix`
- **Parameters:**
  - `etad` (optional): Detector transmissivity, ∈[0,1], default=1.0
  - `etat` (optional): Outcoupling transmissivity, ∈[0,1], default=1.0
  - `N` (optional): Mean photon number, >0, default=0.1
  - `Pd` (optional): Excess noise, ≥0, default=1e-6

#### Get Parameters Info
- **GET** `/api/genqo/spdc/parameters`
- Returns parameter descriptions and valid ranges

## Response Format

### Density Matrix Response
```json
{
  "state_type": "BarrettKokBellPair",
  "parameters": {
    "etaA": 1.0,
    "etaB": 1.0,
    "Pd": 0.0,
    "etad": 1.0,
    "V": 1.0,
    "m": 0
  },
  "density_matrix": {
    "real": [[...], [...], ...],
    "imag": [[...], [...], ...]
  },
  "trace": 1.0,
  "dimensions": [4, 4]
}
```

### Parameters Info Response
```json
{
  "parameters": ["etaA", "etaB", "Pd", "etad", "V"],
  "ranges": {
    "etaA": {"min": 0, "max": 1, "good": 1},
    "etaB": {"min": 0, "max": 1, "good": 1},
    ...
  },
  "description": {
    "etaA": "Individual channel transmissivity from source A...",
    ...
  }
}
```

### Error Response
```json
{
  "error": "Invalid parameters: transmissivities must be in [0,1]"
}
```

## Example Usage

### Using curl

```bash
# Get default Barrett-Kok state
curl "http://localhost:8080/api/barrett-kok/density-matrix"

# Get Barrett-Kok state with custom parameters
curl "http://localhost:8080/api/barrett-kok/density-matrix?etaA=0.9&etaB=0.8&Pd=0.01"

# Get weighted Barrett-Kok state
curl "http://localhost:8080/api/barrett-kok/density-matrix?weighted=true"

# Get available states
curl "http://localhost:8080/api/states"
```

### Using Julia HTTP.jl

```julia
using HTTP, JSON3

# Get Barrett-Kok density matrix
response = HTTP.get("http://localhost:8080/api/barrett-kok/density-matrix?etaA=0.95")
data = JSON3.read(String(response.body))

# Extract the density matrix
ρ_real = data.density_matrix.real
ρ_imag = data.density_matrix.imag
ρ = complex.(ρ_real, ρ_imag)

println("Density matrix trace: ", data.trace)
println("Matrix dimensions: ", data.dimensions)
```

### Using Python requests

```python
import requests
import numpy as np

# Get Barrett-Kok density matrix
response = requests.get("http://localhost:8080/api/barrett-kok/density-matrix",
                       params={"etaA": 0.95, "etaB": 0.90})
data = response.json()

# Reconstruct complex density matrix
rho_real = np.array(data["density_matrix"]["real"])
rho_imag = np.array(data["density_matrix"]["imag"])
rho = rho_real + 1j * rho_imag

print(f"Trace: {data['trace']}")
print(f"Dimensions: {data['dimensions']}")
```

## Quantum States Documentation

### Barrett-Kok Bell Pair
A symbolic representation of the noisy Bell pair state obtained in a Barrett-Kok style protocol (sequence of two successful entanglement swaps). Based on the "dual rail photonic qubit swap" protocol.

**Key Parameters:**
- **etaA, etaB**: Channel transmissivities from sources A and B
- **Pd**: Excess noise in photon detectors
- **etad**: Detection efficiency of photon detectors
- **V**: Mode matching parameter (|V| = mode overlap, arg(V) = phase mismatch)
- **m**: Parity bit from click pattern

### Genqo ZALM (Zero Added Loss Multiplexed)
Heralded multiplexed cascaded source for generating Bell pairs. Uses the Python `genqo` package for calculations.

**Key Parameters:**
- **etab**: Bell state measurement transmissivity
- **etad**: Detector transmissivity
- **etat**: Outcoupling transmissivity
- **N**: Mean photon number (fidelity vs rate tradeoff)
- **Pd**: Excess noise in detectors

### Genqo SPDC
Unheralded spontaneous parametric down-conversion Bell pair source, as described by Kwiat et al.

**Key Parameters:**
- **etad**: Detector transmissivity
- **etat**: Outcoupling transmissivity
- **N**: Mean photon number
- **Pd**: Excess noise in detectors

## Notes

- The density matrices are returned as separate real and imaginary parts to ensure JSON compatibility
- For Genqo states, the Python `genqo` package must be installed and accessible
- All states represent two-qubit systems with 4×4 density matrices
- Parameter validation is performed server-side with appropriate error messages
- The weighted versions return unnormalized density matrices where the trace represents the success probability

# TODO future improvements

The API end points for states and their documentation can be generated programmatically through the available introspection tools of the library. That would make the code a bit less legible, but drastically shorter and easier to maintain. Instead, the current setup will rapidly become outdated as new states are added and the documentation of old states gets improved.