using Test
using QuantumSavory
using Gabs

function test_indexed_gabs_apply(state, indices, operation)
    expected = copy(state)
    apply!(expected, Gabs.embed(state.basis, indices, operation))

    actual = copy(state)
    method = which(apply!, (typeof(actual), typeof(indices), typeof(operation)))
    @test method.module === Gabs
    @test apply!(actual, indices, operation) === actual
    @test actual ≈ expected
end

@testset "Gabs indexed apply! integration" begin
    for Basis in (Gabs.QuadPairBasis, Gabs.QuadBlockBasis)
        single_basis = Basis(1)
        two_mode_basis = Basis(2)
        full_basis = Basis(3)
        state = Gabs.coherentstate(
            full_basis,
            ComplexF64[0.2 + 0.1im, -0.4 + 0.3im, 0.6 - 0.2im],
        )

        test_indexed_gabs_apply(
            state,
            2,
            Gabs.displace(single_basis, 0.11 + 0.07im),
        )
        test_indexed_gabs_apply(
            state,
            [1, 3],
            Gabs.beamsplitter(two_mode_basis, 0.37),
        )
        test_indexed_gabs_apply(
            state,
            2,
            Gabs.attenuator(single_basis, 0.29, 1.2),
        )
        test_indexed_gabs_apply(
            state,
            [1, 3],
            Gabs.attenuator(two_mode_basis, [0.23, 0.41], [1.1, 1.4]),
        )
    end
end
