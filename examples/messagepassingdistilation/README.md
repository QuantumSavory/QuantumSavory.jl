# Chart flow of the protocol

Entanglement (simple channel)

```mermaid
sequenceDiagram
    Alice-->>Alice: FIND_FREE_QUBIT
    Alice->>+Bob: FIND_QUBIT_TO_PAIR
    Bob->>Bob: WAIT_UNTIL_FOUND
    Bob-->>-Alice: ASSIGN_ORIGIN or UNLOCK (if not found)
    Alice->>+Bob: INITIALIZE_STATE
    Bob->>-Alice: GENERATED_ENTANGLEMENT
    Alice->>+Bob: GENERATED_ENTANGLEMENT_REROUTED (process_channel)
    Bob->>+Bob: Lock self (localy)
    Bob->>+Alice: LOCK Alice
    Alice->>Alice: Wait for process to pick up
```
Purification (on process channel)

```mermaid
sequenceDiagram
    Bob-->>+Bob: LOCK and and repeat above diagram until length(indices) == purif_circuit_size
    Bob->>-Bob: Perform purification measurement and send it to Alice

    Bob->>+Alice: PURIFY(local_measurement)
    Alice->>Alice: Perform purification measurement and compare to Bob
    Alice->>Bob: REPORT_SUCCESS
    Alice->>-Alice: Release locks and clear registers based on success
    Bob->>Bob: Release locks and clear registers based on success
```

Coupled purification after entanglement

```mermaid
sequenceDiagram
    Alice-->>Alice: FIND_FREE_QUBIT
    Alice->>+Bob: FIND_QUBIT_TO_PAIR
    Bob->>Bob: WAIT_UNTIL_FOUND
    Bob-->>-Alice: ASSIGN_ORIGIN or UNLOCK (if not found)
    Alice->>+Bob: INITIALIZE_STATE
    Bob->>-Alice: GENERATED_ENTANGLEMENT
    Alice->>+Bob(process_channel): GENERATED_ENTANGLEMENT
    Bob(process_channel)->>Alice: LOCK Alice
    Bob(process_channel)-->>Bob(process_channel): LOCK and WAIT FOR length(indices) == purif_circuit_size
    Bob(process_channel)->>-Bob(process_channel): Perform purification measurement and send it to Alice

    Bob(process_channel)->>+Alice(process_channel): PURIFY(local_measurement)
    Alice(process_channel)->>Alice(process_channel): Perform purification measurement and compare to Bob
    Alice(process_channel)->>Bob(process_channel): REPORT_SUCCESS
    Alice(process_channel)->>-Alice(process_channel): Release locks and clear registers based on success
    Bob(process_channel)->>Bob(process_channel): Release locks and clear registers based on success
```

# Important
if graphs are too large/too little on retina screens specifically on macos,
go to Sim.jl line 13 and modify
```julia
retina_scale = 1 # modify to 2 instead of 1
```
