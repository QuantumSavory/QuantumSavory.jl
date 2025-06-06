using Graphs                        # ≥ v1.9

"""
Return `true` iff every edge of `g` has at least one endpoint in `S`.
Runs in Θ(|E|) time.
"""
function is_vertex_cover(g::AbstractGraph, S::Set{Int})::Bool
    for e in edges(g)
        (src(e) ∈ S || dst(e) ∈ S) || return false
    end
    return true
end

"""
Given a vertex cover S, return a *minimal* vertex cover contained in S
by deleting every redundant vertex. Returns a set with only 0 as an element if S is not a cover.
Runs in Θ(|V| + |E|) time.
"""
function minimal_vertex_cover(g::AbstractGraph, S::Set{Int})::Set{Int}
    is_vertex_cover(g, S) || return Set([0])  # return empty set if S is not a cover

    C = Set(S)                     # non-destructive copy
    for v in C
        neighs = neighbors(g, v)    # get neighbors of v and remove v if all neighbors are in C (then no edge can be uncovered by removing v)
        issubset(neighs, C) && delete!(C, v)  # remove neighbors from C
    end
    return C
end

g = path_graph(5)             # 5-cycle
S = Set([2, 1])             # not minimal

println("Given cover      :", S)
println("Is cover?        ", is_vertex_cover(g, S))
Cmin = minimal_vertex_cover(g, S)
println("Pruned to minimal:", Cmin)
# → {1, 3}