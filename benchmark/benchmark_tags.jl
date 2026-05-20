SUITE["tags"] = BenchmarkGroup(["tags"])

SUITE["tags"]["constructors"] = BenchmarkGroup(["constructors"])

# Generic Tag constructor paths.
SUITE["tags"]["constructors"]["generic_symbol_int_int"] = @benchmarkable Tag(:benchtag, 1, 2)
SUITE["tags"]["constructors"]["generic_symbol_int_int_int"] = @benchmarkable Tag(:benchtag, 1, 2, 3)
SUITE["tags"]["constructors"]["generic_type_int_int"] = @benchmarkable Tag(Int, 1, 2)

# Direct tag variant constructor paths.
SUITE["tags"]["constructors"]["variant_symbol_int_int"] = @benchmarkable tag_types.SymbolIntInt(:benchtag, 1, 2)
SUITE["tags"]["constructors"]["variant_type_int_int"] = @benchmarkable tag_types.TypeIntInt(Int, 1, 2)

# Forward tags are used by message forwarding paths.
_forward_base_tag = Tag(:benchtag, 7, 11)
SUITE["tags"]["constructors"]["variant_forward"] = @benchmarkable tag_types.Forward(_forward_base_tag, 2)

SUITE["tags"]["access"] = BenchmarkGroup(["access"])
_long_tag = Tag(:benchtag, 1, 2, 3, 4, 5, 6)

SUITE["tags"]["access"]["length"] = @benchmarkable length(_long_tag)
SUITE["tags"]["access"]["index_first"] = @benchmarkable _long_tag[1]
SUITE["tags"]["access"]["index_last"] = @benchmarkable _long_tag[7]
SUITE["tags"]["access"]["iterate_collect"] = @benchmarkable collect(_long_tag)
