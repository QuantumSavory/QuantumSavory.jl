"""Assign a tag to a slot in a register.

See also: [`query`](@ref), [`tag_types`](@ref)"""
function tag!(ref::RegRef, tag::Tag)
    push!(ref.reg.tags[ref.idx], tag)
end

"""Wildcard for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`tag_types`](@ref)"""
struct Wildcard end

"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`tag_types`](@ref), [`Wildcard`](@ref)"""
const W = Wildcard()

"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`tag_types`](@ref), [`Wildcard`](@ref)"""
const ❓ = W

""" A query function checking for the first slot in a register that has a given tag.

It supports wildcards (instances of `Wildcard` also available as the constants [`W`](@ref) or [`❓`](@ref) which can be entered as `\\:question:` in the REPL).

```jldoctest
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);
       tag!(r[5], Int, 4, 5);

julia> query(r, :symbol, 4, 5)
(Slot 2, SymbolIntInt(:symbol, 4, 5)::QuantumSavory.Tag)

julia> query(r, :symbol, ❓, 3)
(Slot 1, SymbolIntInt(:symbol, 2, 3)::QuantumSavory.Tag)

julia> query(r, :othersym, ❓, ❓) |> isnothing
true

julia> query(r, Float64, 4, 5) |> isnothing
true
```
"""
function query(reg::Register, tag::Tag)
    i = findfirst(set -> tag ∈ set, reg.tags)
    isnothing(i) ? nothing : (reg[i], tag)
end

_query_all() = true
_query_all(a::Bool) = a
_query_all(a::Bool, b::Bool) = a && b
_query_all(a::Bool, b::Bool, c::Bool) = a && b && c

# Create a query function for each combination of tag arguments and/or wildcard arguments
for (tagsymbol, tagvariant) in pairs(tag_types)
    sig = methods(tagvariant)[1].sig.parameters[2:end]
    args = (:a, :b, :c, :d)[1:length(sig)]
    argssig = [:($a::$t) for (a,t) in zip(args, sig)]

    eval(quote function tag!(ref::RegRef, $(argssig...))
        tag!(ref, ($tagvariant)($(args...)))
    end end)

    eval(quote function query(reg::Register, $(argssig...))
        query(reg, ($tagvariant)($(args...)))
    end end)

    int_idx_all = [i for (i,s) in enumerate(sig) if s == Int]
    int_idx_combs = powerset(int_idx_all, 1)
    for idx in int_idx_combs
        complement_idx = tuple(setdiff(1:length(sig), idx)...)
        sig_wild = collect(sig)
        sig_wild[idx] .= Wildcard
        argssig_wild = [:($a::$t) for (a,t) in zip(args, sig_wild)]
        nonwild_checks = [:(tag.data[$i]==$(args[i])) for i in complement_idx]
        eval(quote function query(reg::Register, $(argssig_wild...))
            for (reg_idx, tags) in enumerate(reg.tags)
                 for tag in tags
                    if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                        if _query_all($(nonwild_checks...))
                            return (reg[reg_idx], tag)
                        end
                    end
                 end
            end
        end end)
    end

end
