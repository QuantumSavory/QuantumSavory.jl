_overlap(l::Symbolic{AbstractKet}, r::Ket) = _overlap(express(l, QOR), r)
_overlap(l::Symbolic{AbstractKet}, r::Operator) = _overlap(express(l, QOR), r)

_project_and_drop(state::Ket, project_on::Symbolic{AbstractKet}, basis_index) = _project_and_drop(state, express(project_on, QOR), basis_index)
_project_and_drop(state::Operator, project_on::Symbolic{AbstractKet}, basis_index) = _project_and_drop(state, express(project_on, QOR), basis_index)

function project_traceout!(state::Union{Ket,Operator},stateindex,basis::Symbolic{AbstractOperator})
    project_traceout!(state::Operator,stateindex,eigvecs(basis))
end

function project_traceout!(state::Union{Ket,Operator},stateindex,basis::Vector{<:Symbolic{AbstractKet}})
    project_traceout!(state::Operator,stateindex,express.(basis,(QOR,)))
end
