# ASPEN-Net entanglement distribution

Run `julia --project=examples examples/aspen_net/1_simple_run.jl` from the repository
root. Two `AspenSourceProt`s send their optical outputs to one `AspenCentralProt`
through quantum channels. The central node returns `AspenHerald` messages through
classical channels. All three protocols use the same `AspenSchedule` and clock.

For heralding probability `p`, the schedule chooses the smallest buffer depth `N`
with `(1 - (1-p)^N)^2 ≥ coincidence_prob`. Each source keeps its first heralded
photon and releases it after `N * attempt_time`. Slot 1 stores the local output of
the unbalanced beam splitter; slot 2 sends the other output to the central node.
The central node has exactly two slots, one for each incoming optical mode.

```mermaid
sequenceDiagram
    participant A as Source A
    participant C as Central node
    participant B as Source B
    Note over A,B: Shared timeslot: buffer the first heralded photon at each source
    Note over A,B: Scheduled release: split between local memory and outgoing mode
    A->>C: Quantum channel: outgoing mode
    B->>C: Quantum channel: outgoing mode
    alt Both modes arrive on time and within the coincidence window
        C->>C: Erase path information and detect a click
        C-->>A: Classical channel: AspenHerald (success or failure)
        C-->>B: Classical channel: AspenHerald (success or failure)
    else A mode is missing or arrivals are too far apart
        C->>C: Discard any arrival
        C-->>A: Classical channel: failure
        C-->>B: Classical channel: failure
    end
    Note over A,B: At acknowledgement deadline: correct and tag success; otherwise discard
    Note over A,B: Consumer frees successful memories for a later timeslot
```

Both deadlines are measured from release. Quantum delays must fit inside
`arrival_timeout`; that timeout plus classical delays must fit inside
`acknowledgement_timeout`. Buffering and acknowledgement must finish before the next
period. These constraints are validated. The central node also requires arrivals
to be separated by at most `coincidence_window`. A failed or missing acknowledgement
erases the local memory; success creates reciprocal `EntanglementCounterpart` tags.

This initial model uses lossless buffering, a stable optical phase, no dark counts,
and qubits for vacuum/single-photon occupancy. Threshold detection can accept a
two-photon event and leave vacuum in both memories. Lower `central_fraction`
suppresses this error at the cost of fewer successes. Text and HTML displays show
timing and outcomes; loading CairoMakie also enables PNG protocol history displays.
