using Yao

Locs = Union{Vector{Int}, Int}
"""
Note: according to Figure 2, page 4 of the paper:

    U(nbits::Int, locs::Union{Vector{Int}, Int}, θ::Real, ϕ::Real, λ::Real)
"""
function U(nbits::Int, locs::Locs, θ::Real, ϕ::Real, λ::Real)
    put(nbits, locs=>Rz(ϕ)*Ry(θ)*Rz(λ))
end

"""
Note: according to the section before Figure 2, page 4 of the paper:

    CX(nbits::Int, locs_c::Union{Vector{Int}, Int}, locs_x::Union{Vector{Int}, Int})

CNOT gate, `locs_c` are control qubits locations and `locs_x` are target qubits locations.
"""
function CX(nbits::Int, locs_c::Locs, locs_x::Locs)
    control(nbits, (locs_c...,), (locs_x...,)=>X)
end