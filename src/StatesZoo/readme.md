## Quick Start

Shown below are the typical values for the parameters and how to call the functions:

```
using QuantumSavory.StatesZoo: cascaded_source_photonic, cascaded_source_spin, midswap_dual_rail, midswap_single_rail
```

#### `cascaded_source_photonic()`

```
Ns = 1e-3
eAs = 1
eBs = 1
eD = 0.9
Pd = 1e-8
VisF = 0.99

cascaded_source_photonic(Ns,eAs,eBs,eD,Pd,VisF)
```

#### `cascaded_source_spin()`

```
Ns = 1e-3
gA = 0.5
gB = 0.5
eAm = 1
eBm = 1
eAs = 1
eBs = 1
eD = 0.9
Pd = 1e-8
Pdo1 = 1e-8
Pdo2 = 1e-8
VisF = 0.99

cascaded_source_spin(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF)
```

#### `midswap_single_rail`

```
eA = 0.9
eB = 0.9
gA = 0.5
gB = 0.5
Pd = 1e-8
Vis = 0.99

midswap_single_rail(eA,eB,gA,gB,Pd,Vis)
```

#### `midswap_dual_rail`

```
eA = 0.9
eB = 0.9
gA = 0.5
gB = 0.5
Pd = 1e-8
Vis = 0.99


midswap_dual_rail(eA,eB,gA,gB,Pd,Vis)
```