using MLStyle
using MLStyle.Record
export trans

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
@as_record Struct_bin

struct Session
    n     :: Ref{Int}
end

function declare_q!(sess::Session, reg::Symbol, amount::Int)
    rng(a, b) = a+1 : a + b
    qbits = collect(rng(sess.n.x, amount))
    sess.n.x += amount
    :($reg = Int[$(qbits...)])
end

macro const_eval(x)
    __module__.eval(x)
end

fake_line_node = LineNumberNode(1, "fake")

get_qbits(sess) = Expr(:macrocall, Symbol("@eval"), fake_line_node, :($sess.n.x))

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

init_sess() = Session(Ref(0))
trans(qasm) = trans(qasm, init_sess())
function trans(qasm, sess::Session)
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end

    rec(qasm) = trans(qasm, sess)
    @match qasm begin
        Struct_pi(_) => Base.pi
        Token{:id}(str=str) => Symbol(str)
        Token{:real}(str=str) => parse(Float64, str)
        Token{:nninteger}(str=str) => parse(Int64, str)
        Struct_neg(value=value) => :(-$(rec(value)))
        Struct_bin(l=l, op=Token(str=op), r=r) => app(op, l, r)
        Struct_fnexp(fn = Token(str=fn), arg=arg) =>
            let fn = @match fn begin
                        "sin" => sin
                        "cos" => cos
                        "tan" => tan
                        "exp" => exp
                        "ln"  => log
                        "sqrt"=> sqrt
                        _     => error("not impl yet")
                    end
                app(fn, arg)
            end

        Struct_idlist(hd=Token(str=hd), tl=nothing) => [Symbol(hd)]
        Struct_idlist(hd=Token(str=hd), tl=tl) => [Symbol(hd), rec(tl)...]

        Struct_explist(hd=hd, tl=nothing) => [rec(hd)]
        Struct_explist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_mixedlist(hd=hd, tl=nothing) => [rec(hd)]
        Struct_mixedlist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_argument(id=Token(str=id), arg=nothing) => Symbol(id)
        Struct_argument(id=Token(str=id), arg=Token(str=int)) =>
            let ind = parse(Int, int) + 1 # due to julia 1-based index
                :($(Symbol(id))[$ind])
            end

        Struct_cx(out1=out1, out2=out2) =>
            let ref1 = rec(out1),
                ref2 = rec(out2)
                :($CX($(get_qbits(sess)), $ref1, $ref2))
            end
        Struct_u(in1=in1, in2=in2, in3=in3, out=out) =>
            let (a, b, c) = map(rec, (in1, in2, in3)),
                ref = :($(rec(out))[1])
                :($U($(get_qbits(sess)), $ref, $a, $b, $c))
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
            let out_ids :: Vector{Symbol} = rec(outs),
                fid = Symbol(fid)
                quote
                    function $fid(($(args...), ), $(out_ids...))
                        chain($(goplist...))
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

                if regtype == "qreg"
                    declare_q!(sess, id, n)
                else
                    :($id = BitArray(undef, $n))
                end
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
