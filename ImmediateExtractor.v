module ImmediateExtractor(
    input [31:0] Instruction,
    input [11:0] Instruction_TYPE,
    output reg signed [63:0] VALUE
);
    //I type immediate
    wire [11:0] IMM_11_0    = Instruction[31:20];
    wire [5:0] SHAMT        = Instruction[25:20];
    //U type immediate
    wire [19:0] IMM_31_12   = Instruction[31:12];
    //S type immediate
    wire [4:0] IMM_4_0      = Instruction[11:7];
    wire [6:0] IMM_11_5     = Instruction[31:25];
    //B type immediate
    wire IMM_11_B           = Instruction[7];
    wire [3:0] IMM_4_1      = Instruction[11:8];
    wire [5:0] IMM_10_5     = Instruction[30:25];
    wire IMM_12             = Instruction[31];
    //J type immediate
    wire [7:0] IMM_19_12    = Instruction[19:12];
    wire IMM_11_J           = Instruction[20];
    wire [9:0] IMM_10_1     = Instruction[30:21];
    wire IMM_20             = Instruction[31];

    // Extend bits and get immediate values of types.    
    wire signed [63:0] Imm_I   = { {52{IMM_11_0[11]}}, IMM_11_0 }; 
    wire signed [63:0] SHAMT_I = SHAMT;
    wire signed [63:0] Imm_U   = { {32{IMM_31_12[19]}}, IMM_31_12, 12'h000 };
    wire signed [63:0] Imm_B   = { {52{IMM_12}}, IMM_11_B, IMM_10_5, IMM_4_1, 1'b0 };
    wire signed [63:0] Imm_S   = { {52{IMM_11_5[6]}}, IMM_11_5, IMM_4_0 };
    wire signed [63:0] Imm_J   = { {44{IMM_20}}, IMM_19_12, IMM_11_J, IMM_10_1, 1'b0 };

    always @(*) begin
        if(Instruction_TYPE[11]) 
                VALUE = SHAMT_I;
            else if(Instruction_TYPE[2] || Instruction_TYPE[3] || Instruction_TYPE[4] || Instruction_TYPE[5] )
                VALUE = Imm_I;
                else if (Instruction_TYPE[6])
                    VALUE = Imm_S;
                    else if (Instruction_TYPE[7])
                        VALUE = Imm_B;
                        else if (Instruction_TYPE[8] || Instruction_TYPE[9])
                            VALUE = Imm_U;
                            else if (Instruction_TYPE[10])
                                VALUE = Imm_J;
                                else
                                    VALUE = 0;
    end
    
endmodule
