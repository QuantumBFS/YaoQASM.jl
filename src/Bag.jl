using YaoBase: AbstractRegister

# This file is copied from YaoExtensions for convenience,
# will be considerd to move to YaoBlocks!
export AbstractBag
"""
    AbstractBag{BT, N}<:TagBlock{BT, N}

Abstract `Bag` is a wrapper of a block that conserves all properties.
Including `mat`, `apply!`, `ishermitian`, `isreflexive`, `isunitary`,
`occupied_locs`, `apply_back!` and `mat_back!`.
"""
abstract type AbstractBag{BT, N}<:TagBlock{BT, N} end

YaoBlocks.mat(::Type{T}, bag::AbstractBag{N}) where {T,N} = mat(T, content(bag))
YaoBlocks.apply!(reg::AbstractRegister, bag::AbstractBag) = apply!(reg, content(bag))
YaoBlocks.ishermitian(bag::AbstractBag) = ishermitian(content(bag))
YaoBlocks.isreflexive(bag::AbstractBag) = isreflexive(content(bag))
YaoBlocks.isunitary(bag::AbstractBag) = isunitary(content(bag))
YaoBlocks.occupied_locs(bag::AbstractBag) = occupied_locs(content(bag))

function YaoBlocks.AD.apply_back!(state, b::AbstractBag, collector)
    YaoBlocks.AD.apply_back!(state, content(b), collector)
end
function YaoBlocks.AD.mat_back!(::Type{T}, b::AbstractBag, adjy, collector) where T
    YaoBlocks.AD.mat_back!(T, content(b), adjy, collector)
end

export Bag, enable_block!, disable_block!, setcontent!, isenabled
"""
    Bag{N}<:TagBlock{AbstractBlock, N}

A bag is a trivil container, but can
    * `setcontent!(bag, content)`
    * `disable_block!(bag)`
    * `enable_block!(bag)`
"""
mutable struct Bag{N}<:AbstractBag{AbstractBlock, N}
    content::AbstractBlock{N}
    mask::Bool
end
Bag(b::AbstractBlock) = Bag(b,true)

YaoBlocks.content(bag::Bag{N}) where N = bag.mask ? bag.content : put(N, 1=>I2)
YaoBlocks.chcontent(bag::Bag, content) = Bag(content)
setcontent!(bag::Bag, content) = (bag.content = content; bag)
disable_block!(b::Bag) = (b.mask = false; b)
enable_block!(b::Bag) = (b.mask = true; b)
isenabled(b::Bag) = b.mask

function YaoBlocks.print_annotation(io::IO, bag::Bag)
    printstyled(io, isenabled(bag) ? "[⊙] " : "[⊗] "; bold=true, color=isenabled(bag) ? :green : :red)
end

function Base.show(io::IO, ::MIME"plain/text", blk::Bag)
    return print_tree(io, blk; title=false, compact=false)
end
