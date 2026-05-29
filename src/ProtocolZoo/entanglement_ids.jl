using Random: rand

const EntanglementID = Int

const _ENTANGLEMENT_ID_MASK = UInt(typemax(EntanglementID))
const NO_ENTANGLEMENT_ID = zero(EntanglementID)

@inline normalize_entanglement_id(id::EntanglementID) =
    EntanglementID(UInt(id) & _ENTANGLEMENT_ID_MASK)

"""
Generate a random entanglement ID
"""
function fresh_entanglement_id()
    id = NO_ENTANGLEMENT_ID
    while id == NO_ENTANGLEMENT_ID
        id = EntanglementID(rand(UInt) & _ENTANGLEMENT_ID_MASK)
    end
    return id
end

"""
Combine two entanglement IDs into a new one. The combination is commutative and associative,
i.e. `combine_entanglement_ids(a, b) == combine_entanglement_ids(b, a)` and
`combine_entanglement_ids(a, combine_entanglement_ids(b, c)) == combine_entanglement_ids(combine_entanglement_ids(a, b), c)`.
Finally, `NO_ENTANGLEMENT_ID` is the identity element for the combination, i.e. `combine_entanglement_ids(a, NO_ENTANGLEMENT_ID) == a`.
"""
function combine_entanglement_ids(a::EntanglementID, b::EntanglementID)
    # Entanglement IDs are stored in `Tag` integer fields, so keep the value in
    # the nonnegative Int range and combine modulo typemax(Int)+1 without signed
    # overflow.
    ua = UInt(a) & _ENTANGLEMENT_ID_MASK
    ub = UInt(b) & _ENTANGLEMENT_ID_MASK
    return EntanglementID((ua + ub) & _ENTANGLEMENT_ID_MASK)
end
