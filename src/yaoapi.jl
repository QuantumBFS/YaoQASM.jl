using Yao

"""
    U(nbits::Int, locs::Vector{Int}, θ::Real, ϕ::Real, λ::Real)

single qubit gate, `locs` is a unit size vector.
"""
function U(nbits::Int, qbit::Int, θ::Real, ϕ::Real, λ::Real)
    put(nbits, qbit=>Rz(ϕ)*Ry(θ)*Rz(λ))
end

"""
    CX(nbits::Int, locs_c::Vector{Int}, locs_x::Vector{Int})

CNOT gate, `locs_c` are control qubits locations and `locs_x` are target qubits locations.
"""
function CX(nbits::Int, locs_c::Vector{Int}, locs_x::Vector{Int})
    control(nbits, (locs_c...,), (locs_x...,)=>X)
end