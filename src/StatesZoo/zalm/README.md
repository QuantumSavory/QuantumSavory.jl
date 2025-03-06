# `SPDC_HMCS_DetailedModelling`

Running
```
echo "UsingFrontEnd[NotebookEvaluate[\"SPDC_HMCS_DetailedModelling.nb\"]]" | math
echo "UsingFrontEnd[NotebookEvaluate[\"HMCS_SwappedWithMemories_DetailedModelling.nb\"]]" | math
```
creates
```
dens_mat_SPDC.m
SPDCTest1.txt
SPDCTest2.txt
SPDCTest3.txt
SPDCTest4.txt
dens_mat_HMCS.m
HMCSTest1.txt
HMCSTest2.txt
HMCSTest3.txt
HMCSTest4.txt
```
and
```
spin_HMCS_elem11.m
spin_HMCS_elem22.m
spin_HMCS_elem23.m
spin_HMCS_elem32.m
spin_HMCS_elem33.m
spin_HMCS_elem44.m
spin_photon_matlab.m
HMCSMemSwapTest1.txt
HMCSMemSwapTest2.txt
HMCSMemSwapTest3.txt
HMCSMemSwapTest4.txt
```

Then running
```
for f in dens_mat_HMCS dens_mat_SPDC spin_HMCS_elem11 spin_HMCS_elem22 spin_HMCS_elem23 spin_HMCS_elem32 spin_HMCS_elem33 spin_HMCS_elem44 spin_photon_matlab
    sed -z -e 's/\.\.\.\n/ /g' -e 's/\.\^/\^/g' -e 's/\.\*/\*/g' -e 's/,/ /g' $f.m > $f.jlexpr
end
```
```
begin; echo "Base.@constprop :aggressive Base.@assume_effects :inaccessiblememonly :foldable function _dens_mat_SPDC(eA, eB, Ns)"; cat dens_mat_SPDC.jlexpr; echo "end"; end > dens_mat_SPDC.jl
begin; echo "Base.@constprop :aggressive Base.@assume_effects :inaccessiblememonly :foldable function _dens_mat_HMCS(eA, eB, eC1, eC2, Ns, Pd, vis)"; cat dens_mat_HMCS.jlexpr; echo "end"; end > dens_mat_HMCS.jl
```




- ToMatlab.m comes from https://library.wolfram.com/infocenter/MathSource/577/#downloads


## Helper function to get all atoms from an expression

```
get_atoms(e::Expr, set) = get_atoms.(e.args, (set,))
get_atoms(s::Symbol, set) = push!(set, s)
get_atoms(a, set) = nothing
get_atoms(e) = get_atoms(e, Set())
get_atoms(Meta.parse(read(FILENAME, String)))
```