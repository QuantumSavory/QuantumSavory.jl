# [Quantum State Visualization](@id quantum-state-visualization)

The quantum states objects in QuantumSavory have a variety of `show` methods
implemented for them. Depending on the IDE you are working in,
you will be able to see rich information about the quantum state you are working with,
e.g. when accessing it with `stateof(network[register_index][slot_index])` or `stateof(register[slot_index])`.

In particular:
- in Pluto or Jupyter or VS Code you will see the `text/html` or `image/png` rendering.
- in the REPL you will see the `text/plain` rendering.

This reference page shows how a five-subsystem `StateRef` is rendered
by the `text/plain`, `text/html`, and `image/png` display backends.

```@setup state_visualization
ENV["COLUMNS"] = "100"
ENV["LINES"] = "24"

using CairoMakie
using QuantumSavory

CairoMakie.activate!()

const STATEVIS_ROWS = 24
const STATEVIS_COLUMNS = 100

function statevis_qubit_register(repr)
    reg = Register(fill(Qubit(), 5), fill(repr, 5))
    initialize!(reg[1], X1)
    for i in 2:5
        initialize!(reg[i], Z1)
    end
    for i in 2:5
        apply!([reg[1], reg[i]], CNOT)
    end
    return QuantumSavory.stateof(reg[1])
end

function statevis_gabs_register()
    reg = Register(fill(Qumode(), 5), fill(GabsRepr(QuantumSavory.Gabs.QuadBlockBasis), 5))
    for i in 1:5
        initialize!(reg[i], SqueezedState(0.15 * i))
        apply!(reg[i], DisplaceOp(0.1 * i - 0.05im * i))
    end
    for i in 1:4
        apply!([reg[i], reg[i + 1]], BeamSplitterOp(1 / 2))
    end
    return QuantumSavory.stateof(reg[1])
end

quantumoptics_state = statevis_qubit_register(QuantumOpticsRepr())
gabs_state = statevis_gabs_register()
quantumclifford_state = statevis_qubit_register(CliffordRepr())

function statevis_plaintext(stateref)
    io = IOBuffer()
    ctx = IOContext(
        io,
        :displaysize => (STATEVIS_ROWS, STATEVIS_COLUMNS),
        :limit => true,
    )
    show(ctx, MIME"text/plain"(), stateref)
    return String(take!(io))
end

function statevis_html(stateref)
    return Base.HTML(sprint(show, MIME"text/html"(), stateref))
end
```

## QuantumOptics State

### `text/plain`

```@example state_visualization
print(statevis_plaintext(quantumoptics_state)) # hide
```

### `text/html`

```@example state_visualization
statevis_html(quantumoptics_state) # hide
```

### `image/png`

![QuantumOptics `StateRef` rendered with the image/png backend](assets/generated/state_visualization/quantumoptics_5subsystems.png)

## Gabs State

### `text/plain`

```@example state_visualization
print(statevis_plaintext(gabs_state)) # hide
```

### `text/html`

```@example state_visualization
statevis_html(gabs_state) # hide
```

### `image/png`

![Gabs `StateRef` rendered with the image/png backend](assets/generated/state_visualization/gabs_5subsystems.png)

## QuantumClifford State

### `text/plain`

```@example state_visualization
print(statevis_plaintext(quantumclifford_state)) # hide
```

### `text/html`

```@example state_visualization
statevis_html(quantumclifford_state) # hide
```

### `image/png`

![QuantumClifford `StateRef` rendered with the image/png backend](assets/generated/state_visualization/quantumclifford_5subsystems.png)
