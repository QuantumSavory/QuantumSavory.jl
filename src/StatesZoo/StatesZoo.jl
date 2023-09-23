module StatesZoo

export cascaded_source_photonic, cascaded_source_spin, midswap_dual_rail, midswap_single_rail


const cascaded_source_basis = [0 0 0 0;
                               0 0 0 1;
                               0 0 0 2;
                               0 0 1 0;
                               0 0 1 1;
                               0 0 2 0;
                               0 1 0 0;
                               0 1 0 1;
                               0 1 0 2;
                               0 1 1 0;
                               0 1 1 1;
                               0 1 2 0;
                               0 2 0 0;
                               0 2 0 1;
                               0 2 0 2;
                               0 2 1 0;
                               0 2 1 1;
                               0 2 2 0;
                               1 0 0 0;
                               1 0 0 1;
                               1 0 0 2;
                               1 0 1 0;
                               1 0 1 1;
                               1 0 2 0;
                               1 1 0 0;
                               1 1 0 1;
                               1 1 0 2;
                               1 1 1 0;
                               1 1 1 1;
                               1 1 2 0;
                               2 0 0 0;
                               2 0 0 1;
                               2 0 0 2;
                               2 0 1 0;
                               2 0 1 1;
                               2 0 2 0]

    
include("cascaded_source.jl")
include("entanglement_swap.jl")
include("ret_cxy.jl")

end # module