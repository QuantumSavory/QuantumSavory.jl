function tag!(ref::RegRef, tag::Tag)
    push!(ref.reg.tags[ref.idx], tag)
end

"""Wildcard for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`tag_types`](@ref)"""
struct Wildcard end

"""A wilcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`tag_types`](@ref)"""
const W = Wildcard()
const ❓

function query(reg::Register, tag::Tag)
    i = findfirst(set -> tag ∈ set, reg.tags)
    isnothing(i) ? nothing : (reg.refs[i], tag)
end

_query_and() = true
_query_and(a::Bool) = a
_query_and(a::Bool, b::Bool) = a && b

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
        complement_idx = tuple(setdiff(int_idx_all, idx)...)
        sig_wild = collect(sig)
        sig_wild[idx] .= Wildcard
        argssig_wild = [:($a::$t) for (a,t) in zip(args, sig_wild)]
        nonwild_checks = [:(tag.data[i]==$(args[i])) for i in complement_idx]
        eval(quote function query(reg::Register, $(argssig_wild...))
            for (reg_idx, tags) in enumerate(reg.tags)
                 for tag in tags
                    if isvariant(tag, $(tagsymbol))
                        if _query_all($(nonwild_checks...)) end
                        return (reg_idx, tag)
                    end
                 end
            end
        end end)
    end

end
