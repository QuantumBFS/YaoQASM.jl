using YaoQASM, Yao
using YaoQASM: U, CX, RESET, Barrier, MEASURE


using Test
@testset "yao api" begin
    # single qubit gate

    uh = U(5, 3, π/2, 0, π)
    @test mat(uh)*im ≈ mat(put(5, 3=>H))

    # cnot gate
    cn = CX(5, [3], [5])
    @test mat(cn) == mat(put(5, (3,5)=>ConstGate.CNOT))

    # reset gate
    rst = RESET(5, [3,5])
    @test rst isa Measure
    rst = RESET(5, 3)
    @test rst isa Measure

    @test Barrier{5}() isa Barrier

    ba = BitArray([false, false, false])
    fl = MEASURE(5, [3,4], view(ba, [2,3]))
    @test fl isa YaoQASM.FlushResults
    product_state(bit"11011") |> fl
    @test ba == BitArray([0,0,1])
end

@testset "YaoQASM.jl" begin
    src1 = """
    OPENQASM 2.0;

    gate cu1(theta) a,b
    {
        U(0,0,theta/2) a;
        CX a,b;
        U(0,0,-theta/2) b;
    }

    qreg q[3];
    qreg a[2];
    creg c[3];
    creg syn[2];
    cu1(pi/2) q[0],q[1];
    """
    @test_broken (string_ast ∘ parse_qasm ∘ lex)(src1) ==
"""YaoQASM.Grammar.Struct_mainprogram(
  ver=Token{real}(str=2.0, lineno=1, colno=1),
  prog=[
    YaoQASM.Grammar.Struct_gate(
      decl=YaoQASM.Grammar.Struct_gatedecl(
        id=Token{id}(str=cu1, lineno=3, colno=3),
        arglist1=Token{id}(str=theta, lineno=3, colno=3),
        arglist2=(
          Token{id}(str=a, lineno=3, colno=3),
          Token{id}(str=b, lineno=3, colno=3),
        ),
      ),
      goplist=[
        YaoQASM.Grammar.Struct_u(
          exprs=(
            (
              Token{nninteger}(str=0, lineno=5, colno=5),
              Token{nninteger}(str=0, lineno=5, colno=5),
            ),
            (
              Token{id}(str=theta, lineno=5, colno=5),
              Token{unnamed}(str=/, lineno=5, colno=5),
              Token{nninteger}(str=2, lineno=5, colno=5),
            ),
          ),
          arg=YaoQASM.Grammar.Struct_argument(
            id=Token{id}(str=a, lineno=5, colno=5),
            arg=nothing,
          ),
        ),
        YaoQASM.Grammar.Struct_cx(
          arg1=YaoQASM.Grammar.Struct_argument(
            id=Token{id}(str=a, lineno=6, colno=6),
            arg=nothing,
          ),
          arg2=YaoQASM.Grammar.Struct_argument(
            id=Token{id}(str=b, lineno=6, colno=6),
            arg=nothing,
          ),
        ),
        YaoQASM.Grammar.Struct_u(
          exprs=(
            (
              Token{nninteger}(str=0, lineno=7, colno=7),
              Token{nninteger}(str=0, lineno=7, colno=7),
            ),
            YaoQASM.Grammar.Struct_neg(
              value=(
                Token{id}(str=theta, lineno=7, colno=7),
                Token{unnamed}(str=/, lineno=7, colno=7),
                Token{nninteger}(str=2, lineno=7, colno=7),
              ),
            ),
          ),
          arg=YaoQASM.Grammar.Struct_argument(
            id=Token{id}(str=b, lineno=7, colno=7),
            arg=nothing,
          ),
        ),
      ],
    ),
    YaoQASM.Grammar.Struct_decl(
      regtype=Token{id}(str=qreg, lineno=10, colno=10),
      id=Token{id}(str=q, lineno=10, colno=10),
      int=Token{nninteger}(str=3, lineno=10, colno=10),
    ),
    YaoQASM.Grammar.Struct_decl(
      regtype=Token{id}(str=qreg, lineno=11, colno=11),
      id=Token{id}(str=a, lineno=11, colno=11),
      int=Token{nninteger}(str=2, lineno=11, colno=11),
    ),
    YaoQASM.Grammar.Struct_decl(
      regtype=Token{id}(str=creg, lineno=12, colno=12),
      id=Token{id}(str=c, lineno=12, colno=12),
      int=Token{nninteger}(str=3, lineno=12, colno=12),
    ),
    YaoQASM.Grammar.Struct_decl(
      regtype=Token{id}(str=creg, lineno=13, colno=13),
      id=Token{id}(str=syn, lineno=13, colno=13),
      int=Token{nninteger}(str=2, lineno=13, colno=13),
    ),
    YaoQASM.Grammar.Struct_iduop(
      op=Token{id}(str=cu1, lineno=14, colno=14),
      lst1=(
        Token{id}(str=pi, lineno=14, colno=14),
        Token{unnamed}(str=/, lineno=14, colno=14),
        Token{nninteger}(str=2, lineno=14, colno=14),
      ),
      lst2=(
        YaoQASM.Grammar.Struct_mixeditem(
          id=Token{id}(str=q, lineno=14, colno=14),
          arg=Token{nninteger}(str=0, lineno=14, colno=14),
        ),
        YaoQASM.Grammar.Struct_mixeditem(
          id=Token{id}(str=q, lineno=14, colno=14),
          arg=Token{nninteger}(str=1, lineno=14, colno=14),
        ),
      ),
    ),
  ],
)"""
    # Write your own tests here.
end

@testset "parse" begin
    src1 = """
    OPENQASM 2.0;

    gate cu1(theta) a,b
    {
        U(0,0,theta/2) a;
        CX a,b;
        U(0,0,-theta/2) b;
    }

    qreg q[3];
    qreg a[2];
    creg c[3];
    creg syn[2];
    cu1(pi/2) q[0],q[1];
    """
    circ = @eval $(trans(parse_qasm(lex(src1))))
    @show circ
    @test mat(circ) ≈ mat(
        chain(put(5, 1=>chain(rot(Z, π/4), rot(Y, 0.0), rot(Z, 0.0))),
            control(5, 1, 2=>X),
            put(5, 2=>chain(rot(Z, -π/4), rot(Y, 0.0), rot(Z, 0.0)))
            ))
    @test syn isa BitArray && length(syn) == 2
    @test c isa BitArray && length(c) == 3
    @test q isa Vector && length(q) == 3
    @test a isa Vector && length(a) == 2
end
