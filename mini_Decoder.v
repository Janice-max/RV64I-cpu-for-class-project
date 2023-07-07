module mini_Decoder(
    input  [31:0] Instruction,
    input         pipeline_update,
    output [63:0] Imm_JUMP,
    output [2:0]  JUMP_TYPE
    );

    wire J_TYPE_JUMP;
    wire I_TYPE_JUMP;
    wire B_TYPE;

    //I type immediate
    wire [11:0] IMM_11_0    = Instruction[31:20];
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
    
    wire signed [63:0] Imm_B   = { {52{IMM_12}}, IMM_11_B, IMM_10_5, IMM_4_1, 1'b0 };
    wire signed [63:0] Imm_J   = { {44{IMM_20}}, IMM_19_12, IMM_11_J, IMM_10_1, 1'b0 };
    wire signed [63:0] Imm_I   = { {52{IMM_11_0[11]}}, IMM_11_0 }; 
        
    assign JUMP_TYPE[0] = pipeline_update? Instruction[6:0] == 7'b1101111: 1'b0; // J_TYPE_JUMP
    assign JUMP_TYPE[1] = pipeline_update? Instruction[6:0] == 7'b1100011: 1'b0; // B_TYPE   
    assign JUMP_TYPE[2] = pipeline_update? Instruction[6:0] == 7'b1100111: 1'b0; // I_TYPE_JUMP 
    
    assign Imm_JUMP = {64{JUMP_TYPE[0]}} & Imm_J |
                      {64{JUMP_TYPE[1]}} & Imm_B |
                      {64{JUMP_TYPE[2]}} & Imm_I;
endmodule