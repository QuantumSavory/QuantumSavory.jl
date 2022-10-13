@withmetadata struct SApplyKet <: Symbolic{Ket}
    op
    ket
end
istree(::SApplyKet) = true
arguments(x::SApplyKet) = [x.op,x.ket]
operation(x::SApplyKet) = *
Base.:(*)(op::Symbolic{Operator}, k::Symbolic{Ket}) = SApplyKet(op,k)
Base.print(io::IO, x::SApplyKet) = begin print(io, x.op); print(io, x.ket) end
basis(x::SApplyKet) = basis(x.ket)

@withmetadata struct SBraKet <: Symbolic{Complex}
    bra
    op
    ket
end
istree(::SBraKet) = true
arguments(x::SBraKet) = [x.bra,x.op,x.ket]
operation(x::SBraKet) = *
#Base.:(*)(b::Symbolic{Bra}, op::Symbolic{Operator}, k::Symbolic{Ket}) = SBraKet(b,op,k)
function Base.print(io::IO, x::SBraKet)
    if isnothing(x.op)
        print(io,string(x.bra)[1:end-1])
        print(io,x.ket)
    else
        print(io.x.bra)
        print(io.x.op)
        print(io.x.ket)
    end
end
