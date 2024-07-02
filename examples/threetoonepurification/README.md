# Single and Double Selection Purification
Purification can be done using one or two pairs of sacrificial qubits. If one uses two pairs instead of one, the output fidelity increases ( especially for higher input fidelities ). 

To measure their performance we start by creating a noisy pair with the given input fidelity `fid`, and then we measure the success probability and final fidelity for a sample of `simcount = 10000` times.

```
noisy_pair = noisy_pair_func(fid)
successcount = 0
finfid = 1
noisy_pair = noisy_pair_func(fid)
for _ in 1:simcount
    r = Register(6, QuantumOpticsRepr())
    initialize!(r[1:2], noisy_pair)
    initialize!(r[3:4], noisy_pair)
    initialize!(r[5:6], noisy_pair)
    output = Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])
    (output) && (successcount = successcount + 1)
    if output
        finfid = observable(r[1:2], projector(bell))
    end
end
```

The success rate is then given by the expression `successcount/simcount`. This are then plotted to yield the image in this same folder.

