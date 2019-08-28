using MLStyle
using MLStyle.Record

using Yao
@as_record Token

@as_record Struct_mainprogram
@as_record Struct_ifstmt
@as_record Struct_gate
@as_record Struct_gatedecl
@as_record Struct_decl
@as_record Struct_barrier_ids
@as_record Struct_reset
@as_record Struct_measure
@as_record Struct_iduop
@as_record Struct_u
@as_record Struct_cx
@as_record Struct_idlist
@as_record Struct_mixedlist
@as_record Struct_argument
@as_record Struct_explist
@as_record Struct_pi
@as_record Struct_fnexp
@as_record Struct_neg
@as_record Struct_exp
@as_record Struct_mul

abstract type AbsCtx{From, To} end
struct Ctx1 <: AbsCtx{:qasm, :qbir}
    qregs :: Vector{Tuple{Symbol, Int}}
    n     :: Ref{Int}
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
    return Int[i + e for e in 1:span]
end

function index_q(ctx1::Ctx1, reg::Symbol, ind::Int)
    Int[index_q(ctx1, reg)[ind]]
end

function declare_q!(ctx::Ctx1, reg::Symbol, amount::Int)
    push!(ctx.qregs, (reg, amount))
    ctx.n.x += n
    nothing
end

fake_line_node = LineNumberNode(1, "fake")

get_qbits(ctx) = Expr(:macrocall, "@eval", fake_line_node, :($ctx.n.x))

const compare_bits(a :: BitArray{1}, b :: I) where I <: Integer =
    begin
        for (bit, ai) in enumerate(a)
            cur = 2 ^ (bit - 1)
            if ((cur & b) !== 0) !== ai
                return false
            end
        end
        true
    end

trans(qasm) = trans(qasm, Ctx1([], Ref(0)))
function trans(qasm, ctx::Ctx1)
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end

    rec(qasm) = trans(qasm, ctx)
    @match qasm begin
        Struct_pi(_) => Base.pi
        Token{:id}(str=str) => parse(Float64, str)
        Token{:real}(str=str) => parse(Float64, str)
        Token{:nninteger}(str=str) => parse(Int64, str)
        Struct_neg(value=value) => :(-$(rec(value)))
        Struct_exp(l=l, op=Token(str=op), r=r) => app(op, l, r)
        Struct_fnexp(fn = Token(str=fn), arg=arg) =>
            let fn = @match fn begin
                        "sin" => sin
                        "cos" => cos
                        _     => error("not impl yet")
                    end
                app(fn, arg)
            end

        Struct_idlist(hd=Token(str=hd), tl=noting) => [Symbol(hd)]
        Struct_idlist(hd=Token(str=hd), tl=tl) => [Symbol(hd), rec(tl)...]

        Struct_explist(hd=hd, tl=nothing) => [rec(hd)]
        Struct_explist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_mixedlist(hd=hd, tl=nothing) => [rec(hd)]
        Struct_mixedlist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_argument(id=Token(str=id), arg=nothing) =>
            index_q(ctx1, Symbol(id))
        Struct_argument(id=Token(str=id), arg=Token(str=int)) =>
            let ind = parse(Int, int) + 1 # due to julia 1-based index
                index_q(ctx1, Symbol(id), ind)
            end

        Struct_cx(out1=out1, out2=out2) =>
            let ref1 = rec(out1),
                ref2 = rec(out2)
                :(CX($(get_qbits(ctx)), $ref1, $ref2))
            end
        Struct_u(in1=in1, in2=in2, in3=in3, out=out) =>
            let (a, b, c) = map(rec, (in1, in2, in3)),
                ref = rec(out)[1]
                :(U($(get_qbits(ctx)), $ref, $a, $b, $c))
            end
        Struct_iduop(gate_name = Token(str=gate_name), args=nothing, outs=outs) =>
            let refs = rec(outs),
                gate_name = Symbol(gate_name)
                :($gate_name((), $(refs...)))
            end
        Struct_iduop(gate_name = Token(str=gate_name), args=exprlist, outs=outs) =>
            let refs = rec(outs),
                exprs = Expr(:tuple, rec(exprlist)...),
                gate_name = Symbol(gate_name)
                :($gate_name($exprs, $(refs...)))
            end
        Struct_gate(
            decl = Struct_gatedecl(
                id=Token(str=fid),
                args= nothing && Do(args=[]) ||
                      idlist  && Do(args = rec(idlist)),
                outs=outs
            ),
            goplist = nothing && Do(goplist=[]) ||
                      goplist && Do(goplist = map(rec, goplist))
         ) =>
            let out_ids :: Vector{Symbol} = rec(outs)
                quote
                    function $fid($(args..., ), $(out_ids...))
                        $(goplist...)
                    end
                end
            end

        Struct_decl(
            regtype = Token(str=regtype),
            id = Token(str=id),
            int = Token(str = n)
        ) =>
            let id = Symbol(id),
                n = parse(Int, n)

                regtype == "qreg" ?
                    declare_q!(ctx, id, n) : :($id = BitArray(undef, $n))
            end
        Struct_ifstmt(l=Token(str=l), r=r, body=body) =>
            let l = Symbol(l),
                r = rec(r),
                body = rec(body)
                :(if $compare_bits($l, $r); $body end)
            end
        Struct_mainprogram(
            prog = stmts
        ) =>
            let stmts = map(rec, stmts)
                Expr(:block, stmts...)
            end
    end
end