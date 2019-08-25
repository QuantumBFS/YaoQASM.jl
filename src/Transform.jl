using MLStyle.Record
using Yao
@as_record Struct_pi
@as_record Struct_fnexp
@as_record Struct_atom
@as_record Struct_mainprogram
@as_record Struct_ifstmt
@as_record Struct_neg
@as_record Token

abstract type AbsCtx{From, To} end
struct Ctx1 <: AbsCtx{:qasm, :qbir}
    qregs :: Vector{Tuple{Symbol, Int}}
end

function index_q(ctx1::Ctx1, reg::Symbol)
    i = 1
    span = 0
    for (k, n) in ctx1.qregs
        span = n
        if k == reg
            break
        end
        i += span
    end
    return (i + e for e in 1:span)
end

function index_q(ctx1::Ctx1, reg::Symbol, ind::Int)
    (index_q(ctx1, reg)[ind], )
end


trans(qasm, ctx) =
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end

    rec(qasm) = trans(qasm, ctx)
    @match qasm begin
        Struct_pi(_) => Base.pi
        Token{:real}(str) => parse(Float64, str)
        Token{:nninteger}(str) => parse(Int64, str)
        Struct_atom(atom) => rec(atom)
        Struct_neg(value) => :(-$(rec(value)))
        Struct_exp(l, op=Token(str=op), r) => app(op, l, r)
        Struct_exp(l, op=Token(str=op), r) => app(op, l, r)
        Struct_fnexp(fn = Token(str=fn), arg) =>
            let fn = @match fn begin
                        "sin" => sin
                        "cos" => cos
                        _     => error("not impl yet")
                    end
                app(fn, arg)
            end
        Struct_explist(hd, nothing) => [rec(hd)]
        Struct_explist(hd, tl) => [rec(hd), rec(tl)...]
        Struct_argument(id=Token(str=id), arg=nothing) =>
            index_q(ctx1, Symbol(id))
        Struct_argument(id=Token(str=id), arg=Token(str=int)) =>
            index_q(ctx1, Symbol(id), parse(Int, int))
        

    end