using YaoBlocks, YaoArrayRegister
using LuxurySparse: IMatrix
using BitBasis: readbit

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

"""
    RESET(nbits::Int, locs::Locs)

The reset operation in Open QASM, note here, instead of keeping the remaining bits in mixed ensemble,
we measure the target qubit directly. See `measure_collapseto!` in `Yao.jl` for detail.
"""
function RESET(nbits::Int, locs::Locs)
    Measure(nbits; locs=locs, resetto=(measure(zero_state(nbits), nshots=1)[1]))
end

"""
    measure(nbits::Int, locs::Locs, cmem)

Measure qubits in location `locs`, and store results to `cmem`.
Here `cmem` is a classical memory that can be specified like `view(bitarray, [2,3])`.
"""
function MEASURE(nbits::Int, locs::Locs, cmem)
    FlushResults(Measure(nbits; locs=locs), cmem)
end

"""
    Barrier{N} <: PrimitiveBlock{N}

The barrier instruction prevents optimizations from reordering gates across its source
line.
"""
struct Barrier{N} <: PrimitiveBlock{N} end
YaoBlocks.mat(b::Barrier{N}) where N = IMatrix{1<<N}()
YaoBlocks.getiparams(b::Barrier) = ()

include("Bag.jl")
"""
    FlushResults{N, C, MT<:Measure{N,C}} <: AbstractBag{MT,N}

The measure wrapper that flushs the output in a `Measure` block to classical memory.
"""
struct FlushResults{N,C,TT, MT<:Measure{N,C}} <: AbstractBag{MT,N}
    content::MT
    target_space::TT
    function FlushResults(mblock::MT, target_space::TT) where {N,C,TT,MT<:Measure{N,C}}
        length(target_space) != C && throw(QubitMismatchError("Expect $C, got target space size $(length(target_space))"))
        new{N,C,TT,MT}(mblock, target_space)
    end
end

function YaoBlocks.apply!(reg::AbstractRegister, fl::FlushResults{N,C}) where {N, C}
    throw(NotImplementedError())
end
function YaoBlocks.apply!(reg::AbstractRegister{1}, fl::FlushResults{N,C}) where {N, C}
    out = apply!(reg, fl.content)
    res = fl.content.results[]
    for i=1:C
        fl.target_space[i] = readbit(res, i)
    end
    return out
end

function YaoBlocks.print_annotation(io::IO, fl::FlushResults)
    printstyled(io, "$(fl.target_space) ← "; bold=true, color=:cyan)
end

function Base.show(io::IO, ::MIME"plain/text", blk::FlushResults)
    return print_tree(io, blk; title=false, compact=false)
end
