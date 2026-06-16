using Random: rand

"""
Integer-backed identifier used for entanglement-tracking bookkeeping.
"""
const EntanglementID = Int

const _ENTANGLEMENT_ID_MASK = UInt(typemax(EntanglementID))
const NO_ENTANGLEMENT_ID = zero(EntanglementID)

@inline normalize_entanglement_id(id::EntanglementID) =
    EntanglementID(reinterpret(UInt, id) & _ENTANGLEMENT_ID_MASK)

"""
Generate a random nonzero entanglement ID.
"""
function fresh_entanglement_id()
    id = NO_ENTANGLEMENT_ID
    while id == NO_ENTANGLEMENT_ID
        id = EntanglementID(rand(UInt) & _ENTANGLEMENT_ID_MASK)
    end
    return id
end

"""
Combine two entanglement IDs into a new one.

The combiner is modular addition over the nonnegative `Int` range. It is
commutative, associative, and has `NO_ENTANGLEMENT_ID` as its identity element.
i.e. `combine_entanglement_ids(a, b) == combine_entanglement_ids(b, a)` and
`combine_entanglement_ids(a, combine_entanglement_ids(b, c)) == combine_entanglement_ids(combine_entanglement_ids(a, b), c)`.
It is not a cryptographic hash and assumes randomly generated IDs, not
adversarial inputs. Two nonzero IDs can combine to `NO_ENTANGLEMENT_ID` with
negligible probability; this is accepted as an extremely unlikely sentinel
collision.
"""
function combine_entanglement_ids(a::EntanglementID, b::EntanglementID)
    # Entanglement IDs are stored in `Tag` integer fields, so keep the value in
    # the nonnegative Int range and combine modulo typemax(Int)+1 without signed
    # overflow.
    ua = UInt(normalize_entanglement_id(a))
    ub = UInt(normalize_entanglement_id(b))
    return EntanglementID((ua + ub) & _ENTANGLEMENT_ID_MASK)
end
