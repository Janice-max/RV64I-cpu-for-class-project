module Decoder(
    input  [31:0] Instruction,
    output [63:0] Immediate_value,
    output [55:0] Instruction_CODE,
    output [11:0] Instruction_TYPE,
    output [4:0]  R1,
    output [4:0]  R2,
    output [4:0]  RD
    );


    // WIRE DEFINITIONS:
    wire [6:0] OPCODE   = Instruction[6:0];
    wire [2:0] FUNCT3   = Instruction[14:12];
    wire [6:0] FUNCT7   = Instruction[31:25];
    wire [6:0] FUNCT6   = Instruction[31:26];

    assign Instruction_TYPE[0]  = OPCODE == 7'h3B;     //R_TYPE_32
    assign Instruction_TYPE[1]  = OPCODE == 7'h33;     //R_TYPE_64
    assign Instruction_TYPE[2]  = OPCODE == 7'h03;   //I_TYPE_LOAD
    assign Instruction_TYPE[3]  = OPCODE == 7'h1B;     //I_TYPE_32
    assign Instruction_TYPE[4]  = OPCODE == 7'h13;     //I_TYPE_64
    assign Instruction_TYPE[5]  = OPCODE == 7'h67;   //I_TYPE_JUMP
    assign Instruction_TYPE[6]  = OPCODE == 7'h23;        //S_TYPE 
    assign Instruction_TYPE[7]  = OPCODE == 7'h63;        //B_TYPE
    assign Instruction_TYPE[8]  = OPCODE == 7'h37;   //U_TYPE_LOAD
    assign Instruction_TYPE[9]  = OPCODE == 7'h17;  //U_TYPE_AUIPC
    assign Instruction_TYPE[10] = OPCODE == 7'h6F;   //J_TYPE_JUMP
    assign Instruction_TYPE[11] = Instruction_CODE[23] || Instruction_CODE[28:27] || Instruction_CODE[34:32]; //I_SHAMT
    
    // -- Immediate Extractor
    ImmediateExtractor ImmediateExtractor( Instruction, Instruction_TYPE, Immediate_value);

    // -- Register-Register Types (R-Type)    
    // ---- RV64I:
    assign Instruction_CODE[0] = Instruction_TYPE[1] && FUNCT3 == 3'h0 && FUNCT7 == 7'h00;  //R_add
    assign Instruction_CODE[1] = Instruction_TYPE[1] && FUNCT3 == 3'h0 && FUNCT7 == 7'h20;  //R_sub
    assign Instruction_CODE[2] = Instruction_TYPE[1] && FUNCT3 == 3'h1 && FUNCT7 == 7'h00;  //R_sll
    assign Instruction_CODE[3] = Instruction_TYPE[1] && FUNCT3 == 3'h2 && FUNCT7 == 7'h00;  //R_slt
    assign Instruction_CODE[4] = Instruction_TYPE[1] && FUNCT3 == 3'h3 && FUNCT7 == 7'h00;  //R_sltu
    assign Instruction_CODE[5] = Instruction_TYPE[1] && FUNCT3 == 3'h4 && FUNCT7 == 7'h00;  //R_xor
    assign Instruction_CODE[6] = Instruction_TYPE[1] && FUNCT3 == 3'h5 && FUNCT7 == 7'h00;  //R_srl
    assign Instruction_CODE[7] = Instruction_TYPE[1] && FUNCT3 == 3'h5 && FUNCT7 == 7'h20;  //R_sra
    assign Instruction_CODE[8] = Instruction_TYPE[1] && FUNCT3 == 3'h6 && FUNCT7 == 7'h00;  //R_or
    assign Instruction_CODE[9] = Instruction_TYPE[1] && FUNCT3 == 3'h7 && FUNCT7 == 7'h00;  //R_and
    // ---- RV64M:
    // assign Instruction_CODE[10] = Instruction_TYPE[1] && FUNCT3 == 3'h0 && FUNCT7 == 7'h01; //R_mul
    // assign Instruction_CODE[11] = Instruction_TYPE[1] && FUNCT3 == 3'h1 && FUNCT7 == 7'h01; //R_mulh
    // assign Instruction_CODE[12] = Instruction_TYPE[1] && FUNCT3 == 3'h6 && FUNCT7 == 7'h01; //R_rem
    // assign Instruction_CODE[13] = Instruction_TYPE[1] && FUNCT3 == 3'h4 && FUNCT7 == 7'h01; //R_div
    assign Instruction_CODE[13:10] = 4'b0;
    // ---- RV32I:
    assign Instruction_CODE[14] = Instruction_TYPE[0] && FUNCT3 == 3'h0 && FUNCT7 == 7'h00; //R_addw
    assign Instruction_CODE[15] = Instruction_TYPE[0] && FUNCT3 == 3'h0 && FUNCT7 == 7'h20; //R_subw
    assign Instruction_CODE[16] = Instruction_TYPE[0] && FUNCT3 == 3'h1 && FUNCT7 == 7'h00; //R_sllw
    assign Instruction_CODE[17] = Instruction_TYPE[0] && FUNCT3 == 3'h5 && FUNCT7 == 7'h00; //R_srlw
    assign Instruction_CODE[18] = Instruction_TYPE[0] && FUNCT3 == 3'h5 && FUNCT7 == 7'h20; //R_sraw
    // ---- RV32M:
    assign Instruction_CODE[19] = Instruction_TYPE[0] && FUNCT3 == 3'h0 && FUNCT7 == 7'h01; //R_mulw
    // assign Instruction_CODE[20] = Instruction_TYPE[0] && FUNCT3 == 3'h4 && FUNCT7 == 7'h01; //R_divw
    // assign Instruction_CODE[21] = Instruction_TYPE[0] && FUNCT3 == 3'h6 && FUNCT7 == 7'h01; //R_remw
    assign Instruction_CODE[21:20] = 2'b0;

    // -- Immediate Types (I-Type)
    // ---- RV64I:
    assign Instruction_CODE[22] = Instruction_TYPE[4] && FUNCT3 == 3'h0;                    //I_addi
    assign Instruction_CODE[23] = Instruction_TYPE[4] && FUNCT3 == 3'h1;                    //I_slli
    assign Instruction_CODE[24] = Instruction_TYPE[4] && FUNCT3 == 3'h2;                    //I_slti
    assign Instruction_CODE[25] = Instruction_TYPE[4] && FUNCT3 == 3'h3;                    //I_sltiu
    assign Instruction_CODE[26] = Instruction_TYPE[4] && FUNCT3 == 3'h4;                    //I_xori 
    assign Instruction_CODE[27] = Instruction_TYPE[4] && FUNCT3 == 3'h5 && FUNCT6 == 6'h00; //I_srli
    assign Instruction_CODE[28] = Instruction_TYPE[4] && FUNCT3 == 3'h5 && FUNCT6 == 6'h10; //I_srai
    assign Instruction_CODE[29] = Instruction_TYPE[4] && FUNCT3 == 3'h6;                    //I_ori
    assign Instruction_CODE[30] = Instruction_TYPE[4] && FUNCT3 == 3'h7;                    //I_andi
    // ---- RV32I:
    assign Instruction_CODE[31] = Instruction_TYPE[3] && FUNCT3 == 3'h0;                    //I_addiw
    assign Instruction_CODE[32] = Instruction_TYPE[3] && FUNCT3 == 3'h1;                    //I_slliw
    assign Instruction_CODE[33] = Instruction_TYPE[3] && FUNCT3 == 3'h5 && FUNCT6 == 7'h00; //I_srliw
    assign Instruction_CODE[34] = Instruction_TYPE[3] && FUNCT3 == 3'h5 && FUNCT6 == 7'h10; //I_sraiw
    // ---- Load
    assign Instruction_CODE[35] = Instruction_TYPE[2] && FUNCT3 == 3'h0; //I_lb
    assign Instruction_CODE[36] = Instruction_TYPE[2] && FUNCT3 == 3'h4; //I_lbu
    assign Instruction_CODE[37] = Instruction_TYPE[2] && FUNCT3 == 3'h1; //I_lh
    assign Instruction_CODE[38] = Instruction_TYPE[2] && FUNCT3 == 3'h5; //I_lhu
    assign Instruction_CODE[39] = Instruction_TYPE[2] && FUNCT3 == 3'h2; //I_lw
    assign Instruction_CODE[40] = Instruction_TYPE[2] && FUNCT3 == 3'h6; //I_lwu
    assign Instruction_CODE[41] = Instruction_TYPE[2] && FUNCT3 == 3'h3; //I_ld
    // ---- Jump
    assign Instruction_CODE[42] = Instruction_TYPE[5];  //I_jalr

    // -- Upper Immediate Types (U-Type)
    assign Instruction_CODE[43] = Instruction_TYPE[8];  //U_lui
    assign Instruction_CODE[44] = Instruction_TYPE[9];  //U_auipc

    // -- Jump Types (J-Type)
    assign Instruction_CODE[45] = Instruction_TYPE[10];  //J_jal

    // -- Store Types (S-Type)
    assign Instruction_CODE[46] = Instruction_TYPE[6] && FUNCT3 == 3'h0;   //S_sb
    assign Instruction_CODE[47] = Instruction_TYPE[6] && FUNCT3 == 3'h1;   //S_sh
    assign Instruction_CODE[48] = Instruction_TYPE[6] && FUNCT3 == 3'h2;   //S_sw
    assign Instruction_CODE[49] = Instruction_TYPE[6] && FUNCT3 == 3'h3;   //S_sd 

    // -- Branch Types (B-Type)
    assign Instruction_CODE[50] = Instruction_TYPE[7] && FUNCT3 == 0;      //B_beq
    assign Instruction_CODE[51] = Instruction_TYPE[7] && FUNCT3 == 1;      //B_bne
    assign Instruction_CODE[52] = Instruction_TYPE[7] && FUNCT3 == 4;      //B_blt
    assign Instruction_CODE[53] = Instruction_TYPE[7] && FUNCT3 == 5;      //B_bge
    assign Instruction_CODE[54] = Instruction_TYPE[7] && FUNCT3 == 6;      //B_bltu
    assign Instruction_CODE[55] = Instruction_TYPE[7] && FUNCT3 == 7;      //B_bgeu

    assign R1 = Instruction[19:15];
    assign R2 = Instruction[24:20];
    assign RD = Instruction[11:7];

endmodule