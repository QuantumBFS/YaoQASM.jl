using Yao

"""
    U(nbits::Int, locs::Vector{Int}, θ::Real, ϕ::Real, λ::Real)

single qubit gate, `locs` is a unit size vector.
"""
function U(nbits::Int, locs::Vector{Int}, θ::Real, ϕ::Real, λ::Real)
    length(locs) == 1 || throw(ArgumentError("input `locs` size must be 1, got $(length(locs))"))
    put(nbits, locs[]=>Rz(ϕ)*Ry(θ)*Rz(λ))
end

"""
    CX(nbits::Int, locs_c::Vector{Int}, locs_x::Vector{Int})

CNOT gate, `locs_c` are control qubits locations and `locs_x` are target qubits locations.
"""
function CX(nbits::Int, locs_c::Vector{Int}, locs_x::Vector{Int})
    control(nbits, (locs_c...,), (locs_x...,)=>X)
end

using Test
@testset "yao api" begin
    # single qubit gate
    @test_throws ArgumentError U(5, [3,4], π/2,0,0)

    uh = U(5, [3], π/2, 0, π)
    @test mat(uh)*im ≈ mat(put(5, 3=>H))

    # cnot gate
    cn = CX(5, [3], [5])
    @test mat(cn) == mat(put(5, (3,5)=>ConstGate.CNOT))
end
