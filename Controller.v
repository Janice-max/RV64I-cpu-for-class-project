module Controller(
    input [11:0] Instruction_TYPE,
    input [55:0] Instruction_CODE,
    // 控制信号
    output reg RDWrite,           // Write to register file.
    output reg R1Read,
    output reg R2Read,
    output reg Is32Bit,           // RV32
    output reg [14:0] ALU_OP,     // ALU operation selection.
    output reg [3:0]  ALU_X1_SRC, // ALU source selection.
    output reg [5:0]  ALU_X2_SRC  // ALU source selection.
    );
   
    always@(*) begin
        //寄存器数据相关控制信号
        Is32Bit  =  Instruction_TYPE[0] || Instruction_TYPE[3]; 
        RDWrite  =  !(Instruction_TYPE[6] || Instruction_TYPE[7]);
        R1Read   =  !(Instruction_TYPE[8] || Instruction_TYPE[9] || Instruction_TYPE[10]);
        R2Read   =  Instruction_TYPE[0] || Instruction_TYPE[1] || Instruction_TYPE[6] || Instruction_TYPE[7];    

        // ALU Operation Selection  
        ALU_OP[0]  = Instruction_CODE[0] || Instruction_CODE[14] || Instruction_CODE[22] || Instruction_CODE[31] || Instruction_CODE[49:35]; // add
        ALU_OP[1]  = Instruction_CODE[1] || Instruction_CODE[15]; // sub
        ALU_OP[2]  = Instruction_CODE[9] || Instruction_CODE[30]; // and
        ALU_OP[3]  = Instruction_CODE[8] || Instruction_CODE[29]; // or
        ALU_OP[4]  = Instruction_CODE[5] || Instruction_CODE[26]; // xor
        ALU_OP[5]  = Instruction_CODE[2] || Instruction_CODE[16] || Instruction_CODE[23] || Instruction_CODE[32]; // shift left logical
        ALU_OP[6]  = Instruction_CODE[6] || Instruction_CODE[17] || Instruction_CODE[27] || Instruction_CODE[33]; // shift right logical
        ALU_OP[7]  = Instruction_CODE[7] || Instruction_CODE[18] || Instruction_CODE[28] || Instruction_CODE[34]; // shift right arithmetic
        ALU_OP[8]  = Instruction_CODE[10] || Instruction_CODE[19]; // mulw
        //ALU_OP[9]  = Instruction_CODE[11];  // mulh
        //ALU_OP[10] = Instruction_CODE[13] || Instruction_CODE[20]; // div
        //ALU_OP[11] = Instruction_CODE[12] || Instruction_CODE[21]; // rem
        ALU_OP[9] = 0;
        ALU_OP[10] = 0;
        ALU_OP[11] = 0;
        ALU_OP[12] = Instruction_CODE[3] || Instruction_CODE[24] || Instruction_CODE[53:52]; // set less than (slt)
        ALU_OP[13] = Instruction_CODE[4] || Instruction_CODE[25] || Instruction_CODE[55:54]; // set less than (sltu)
        //ALU_OP[14] = Instruction_CODE[50] || Instruction_CODE[51]; // set equal
        ALU_OP[14] = 0;

        // ALU Source Selection
        ALU_X1_SRC[0] = Instruction_TYPE[1] || Instruction_TYPE[4] || Instruction_TYPE[2] || Instruction_TYPE[7:5]; //R1_DATA
        ALU_X1_SRC[1] = Instruction_TYPE[0] || Instruction_TYPE[3];  //{{32{R1_DATA[31]}}, R1_DATA[31:0]}
        ALU_X1_SRC[2] = Instruction_TYPE[9] || Instruction_TYPE[10]; //PC
        ALU_X1_SRC[3] = Instruction_TYPE[8]; //0

        ALU_X2_SRC[0] = (Instruction_TYPE[1] && !(Instruction_CODE[2] || Instruction_CODE[7:6])) || Instruction_TYPE[7]; //R2_DATA
        ALU_X2_SRC[1] = Instruction_CODE[2] || Instruction_CODE[7:6]; //{{58{R2_DATA[5]}}, R2_DATA[5:0]};
        ALU_X2_SRC[2] = (Instruction_CODE[18:16] > 0); //{{59{R2_DATA[4]}}, R2_DATA[4:0]};
        ALU_X2_SRC[3] = (Instruction_CODE[15:14] > 0 || Instruction_CODE[21:19] > 0); //{{32{R2_DATA[31]}}, R2_DATA[31:0]};
        ALU_X2_SRC[4] = Instruction_TYPE[4:2] || Instruction_TYPE[6] || Instruction_TYPE[9:8]; //IMMEDIATE_VALUE;
        ALU_X2_SRC[5] = Instruction_TYPE[5] || Instruction_TYPE[10]; //4 

         
    end 
  
endmodule