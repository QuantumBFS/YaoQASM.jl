""" Check https://arxiv.org/pdf/1707.03429.pdf for grammar specification
"""
module Grammar
using RBNF
using PrettyPrint
export lex, parse_qasm, Token, print_ast, string_ast

struct QASMLang end

second((a, b)) = b
second(vec::V) where V <: AbstractArray = vec[2]

RBNF.@parser QASMLang begin
    # define ignorances
    ignore{space}

    @grammar
    # define grammars
    mainprogram := ["OPENQASM", ver=real, ';', prog=program]
    program     = statement{*}
    statement   = (decl | gate | opaque | qop | ifstmt | barrier)
    # stmts
    ifstmt      := ["if", '(', l=id, "==", r=nninteger, ')', body=qop]
    opaque      := ["opaque", id=id, ['(', [arglist1=idlist].?, ')'].? , arglist2=idlist, ';']
    barrier     := ["barrier", value=mixedlist]
    decl        := [regtype="qreg" | "creg", id=id, '[', int=nninteger, ']', ';']

    # gate
    gate        := [decl=gatedecl, [goplist=goplist].?, '}']
    gatedecl    := ["gate", id=id, ['(', [arglist1=idlist].?, ')'].?, arglist2=idlist, '{']

    goplist     = (uop |barrier_ids){*}
    barrier_ids := ["barrier", ids=idlist, ';']
    # qop
    qop         = (uop | measure | reset)
    reset       := ["reset", arg=argument, ';']
    measure     := ["measure", arg1=argument, "->", arg2=argument, ';']

    uop         = (iduop | u | cx)
    iduop      := [op=id, ['(', [lst1=explist].?, ')'].?, lst2=mixedlist, ';']
    u          := ['U', '(', exprs=explist, ')', arg=argument, ';']
    cx         := ["CX", arg1=argument, ',', arg2=argument, ';']

    idlist     = @direct_recur begin
        init = id
        prefix = (recur, (',', id) % second)
    end

    mixeditem   := [id=id, ['[', arg=nninteger, ']'].?]
    mixedlist   = @direct_recur begin
        init = mixeditem
        prefix = (recur, (',', mixeditem) % second)
    end

    argument   := [id=id, ['[', (arg=nninteger), ']'].?]

    explist    = @direct_recur begin
        init = exp
        prefix = (recur,  (',', exp) % second)
    end

    atom       = (real | nninteger | "pi" | id | fnexp) | (['(', exp, ')'] % second) | neg
    fnexp      := [fn=fn, '(', arg=exp, ')']
    neg        := ['-', value=exp]
    exp        = @direct_recur begin
        init = atom
        prefix = (recur, binop, atom)
    end
    fn         = ("sin" | "cos" | "tan" | "exp" | "ln" | "sqrt")
    binop      = ('+' | '-' | '*' | '/')

    # define tokens
    @token
    id        := r"\G[a-z]{1}[A-Za-z0-9_]*"
    real      := r"\G([0-9]+\.[0-9]*|[0-9]*\.[0.9]+)([eE][-+]?[0-9]+)?"
    nninteger := r"\G([1-9]+[0-9]*|0)"
    space     := r"\G\s+"
end


Token = RBNF.Token

function lex(src :: String)
    RBNF.runlexer(QASMLang, src)
end

function parse_qasm(tokens :: Vector{Token{A} where A})
    ast, ctx = RBNF.runparser(mainprogram, tokens)
    ast
end

print_ast = PrettyPrint.pprint
string_ast = PrettyPrint.pformat

end