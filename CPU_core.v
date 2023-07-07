module CPU_core(
    input           clk,
    input           rstn,

    // with memory_access_ctrl        
    input               Mem_ready,          // 1-memory可读/写
    output              Mem_r_enable,       // 读mem使能信号，cpu发出读memory请求
    input       [63:0]  Mem_r_Data,         
    output      [63:0]  Mem_rw_addr,
    output              Mem_w_enable,       // 写mem使能信号，cpu发出写memory请求
    output      [63:0]  Mem_w_Data,
    output      [2:0]   Mem_rw_bytes        // 读写字节数
);

    // 控制信号
    wire                RDWrite;          // Write to RD.
    wire                R1Read;
    wire                R2Read;
    wire                Is32Bit;          // RV32
    wire        [14:0]  ALU_OP;           // ALU operation selection.
    wire        [3:0]   ALU_X1_SRC;       // ALU source selection.
    wire        [5:0]   ALU_X2_SRC;       // ALU source selection.

    // PC寄存器
    reg         [63:0]  PC;


    // 流水线寄存器
    // --控制相关
    reg         [11:0]  Instruction_TYPE_Pipeline_WB;   // Instruction_TYPE
    reg         [11:0]  Instruction_TYPE_Pipeline_MEM;  // Instruction_TYPE
    reg         [11:0]  Instruction_TYPE_Pipeline_EXE;  // Instruction_TYPE
    reg                 RDWrite_Pipeline_WB;            // RDWrite
    reg                 RDWrite_Pipeline_MEM;           // RDWrite
    reg                 RDWrite_Pipeline_EXE;           // RDWrite
    reg                 R1Read_Pipeline_EXE;            // R1Read
    reg                 R2Read_Pipeline_EXE;            // R2Read
    reg                 Is32Bit_Pipeline_EXE;           // RV32
    reg         [14:0]  ALU_OP_Pipeline_EXE;            // ALU_OP
    reg         [3:0]   ALU_X1_SRC_Pipeline_EXE;        // ALU_X1_SRC  
    reg         [5:0]   ALU_X2_SRC_Pipeline_EXE;        // ALU_X2_SRC
    // --数据相关
    reg         [31:0]  Instruction_Pipeline_WB;       // Instruction
    reg         [31:0]  Instruction_Pipeline_MEM;       // Instruction
    reg         [31:0]  Instruction_Pipeline_EXE;       // Instruction
    reg         [31:0]  Instruction;                    // Instruction_ID
    reg         [63:0]  PC_Pipeline_EXE;                // PC
    reg         [63:0]  PC_Pipeline_ID;                 // PC
    reg         [4:0]   R1_Pipeline_EXE;                // R1
    reg         [4:0]   R2_Pipeline_EXE;                // R2
    reg         [4:0]   RD_Pipeline_WB;                 // RD
    reg         [4:0]   RD_Pipeline_MEM;                // RD
    reg         [4:0]   RD_Pipeline_EXE;                // RD
    reg signed  [63:0]  R1_Data_Pipeline_EXE;           // R1_Data
    reg signed  [63:0]  R2_Data_Pipeline_MEM;           // R2_Data
    reg signed  [63:0]  R2_Data_Pipeline_EXE;           // R2_Data
    reg         [63:0]  Immediate_value_Pipeline_EXE;   // Immediate_value
    reg         [63:0]  ALU_OUT_Pipeline_WB;            // ALU_OUT
    reg         [63:0]  ALU_OUT_Pipeline_MEM;           // ALU_OUT
    reg         [63:0]  Mem_r_Data_Pipeline_WB;         // Mem_r_Data      
    reg         [31:0]  Instruction_temp;   

    // 数据相关冒险信号
    reg                 Data_Dependency_1a;
    reg                 Data_Dependency_1b;
    reg                 Data_Dependency_2a;                
    reg                 Data_Dependency_2b;
    reg                 Data_Dependency_3a;                  
    reg                 Data_Dependency_3b;
    reg                 Data_Dependency_load_use;
    // 控制冒险信号
    reg                 PC_JUMP_EXECUTE;

    // ALU端口
    wire        [63:0]  ALU_X1;
    wire        [63:0]  ALU_X2;
    wire        [63:0]  ALU_OUT;

    // 写回数据
    wire        [63:0]  RD_WB_Data;
   
   // 其他信号
    wire        [63:0]  R1_Data;
    wire        [63:0]  R2_Data;
    wire signed [63:0]  R1_Data_Selected; 
    wire signed [63:0]  R2_Data_Selected;
    wire        [63:0]  unsigned_R1_Data_Selected = R1_Data_Selected;
    wire        [63:0]  unsigned_R2_Data_Selected = R2_Data_Selected;
    wire        [63:0]  Immediate_value;
    wire        [55:0]  Instruction_CODE;
    wire        [11:0]  Instruction_TYPE;
    wire        [4:0]   R1;
    wire        [4:0]   R2;
    wire        [4:0]   RD;

    // 读写memory状态机
    reg                 state;
    reg                 nxt_state;

    // I Cahce
    wire        [31:0]  Instruction_I_Cache;
    wire                I_Cache_ready;
    wire                I_Cache_req_Mem;
    

    // IF阶段minni_Decoder
    wire        [63:0]  Imm_JUMP;
    wire        [2:0]   JUMP_TYPE;

    // 分支预测
    reg                 Branch_COND_true;

    // 流水线控制
    // 冲刷流水线，高电平生效
    wire                flush_ID;
    wire                flush_EXE;
    // 流水线更新条件
    reg                 pipeline_update;
    

    // == MEM interaction ==================================================
    always @(posedge clk or negedge rstn) begin
        if(!rstn) state <= 2'b0;
        else state <= nxt_state;
    end

    always@(*) begin
        case(state)
            1'b0: begin 
            //处理IF阶段的memory读请求
            //Mem_ready & !state时，若同时期的MEM stage没有Memory访问需求，流水线寄存器可更新，否则阻塞
                if(I_Cache_ready) nxt_state = (Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6])? 1'b1: 1'b0;
                else nxt_state = 1'b0; // 阻塞直到Mem_ready
            end
            1'b1: begin 
            //取指完成后，将继续处理MEM stage的memory读写请求
            //Mem_ready & state时，流水线寄存器可更新
                if(Mem_ready) nxt_state = 1'b0;
                else nxt_state = 1'b1; //阻塞直到Mem_ready
            end
        endcase   
        
        if(Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6]) 
            pipeline_update = (state) & Mem_ready;  //若MEM stage没有Memory访问需求，待访问完成，流水线寄存器可更新
        else //MEM stage没有Memory访问需求
            pipeline_update = (!state) & I_Cache_ready; //取值完成，流水线寄存器可更新
    end

    //state == 0: 从MEM读取指令
    //state == 1: store/load指令向MEM读写数据
    assign Mem_r_enable  =   (!state && I_Cache_req_Mem) | (state & Instruction_TYPE_Pipeline_MEM[2]);
    assign Mem_w_enable  =   state & Instruction_TYPE_Pipeline_MEM[6];
    assign Mem_rw_addr   =   {64{!state}} & PC | 
                             {64{state}} & ALU_OUT_Pipeline_MEM;
    assign Mem_rw_bytes  =   {3{!state}} & 3'b010 | 
                             {3{state}} & Instruction_Pipeline_MEM[14:12];
    assign Mem_w_Data    =   {64{state & Instruction_TYPE_Pipeline_MEM[6]}} & R2_Data_Pipeline_MEM; 
    
    
    // == I Cache interaction ==================================================
    I_Cache I_Cache (.clk(clk),
                    .rstn(rstn),
                    .addr(PC[31:0]),
                    .rd_req(!state),
                    .wr_data(Mem_r_Data[31:0]),
                    .Inst_ready(Mem_ready && !state),
                    .rd_data(Instruction_I_Cache),
                    .cache_ready(I_Cache_ready),
                    .I_Cache_req_Mem(I_Cache_req_Mem)
                    );
    
    
    //== 数据相关冒险条件 ======================================================
    always@(*) begin
        // EX／MEM段数据相关检测条件，在EXE阶段检出
        Data_Dependency_1a = !Instruction_TYPE_Pipeline_MEM[2] //不是I_TYPE_LOAD类指令
                        &&  RD_Pipeline_MEM != 0
                        &&  R1_Pipeline_EXE == RD_Pipeline_MEM
                        &&  RDWrite_Pipeline_MEM //需要写回RD
                        &&  R1Read_Pipeline_EXE; //需要读取R1
        Data_Dependency_1b = !Instruction_TYPE_Pipeline_MEM[2] //不是I_TYPE_LOAD类指令
                        &&  RD_Pipeline_MEM != 0
                        &&  R2_Pipeline_EXE == RD_Pipeline_MEM
                        &&  RDWrite_Pipeline_MEM //需要写回RD
                        &&  R2Read_Pipeline_EXE; //需要读取R2
        
        // MEM／WB段数据相关检测条件，在EXE阶段检出
        // 1a,1b冒险需排除load use相关的情况
        Data_Dependency_2a =  RD_Pipeline_WB != 0
                        &&  R1_Pipeline_EXE == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R1Read_Pipeline_EXE //需要读取R1
                        &&  R1_Pipeline_EXE != RD_Pipeline_MEM; //不是MEM／WB段数据相关
                        
        Data_Dependency_2b = RD_Pipeline_WB != 0
                        &&  R2_Pipeline_EXE == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R2Read_Pipeline_EXE //需要读取R2
                        &&  R2_Pipeline_EXE != RD_Pipeline_MEM; //不是MEM／WB段数据相关
        
        // WB段的相关，寄存器同一个周期既写又读，在ID阶段检出
        Data_Dependency_3a = RD_Pipeline_WB != 0
                        &&  Instruction[19:15] == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R1Read //需要读取R1
                        &&  R1_Pipeline_EXE != RD_Pipeline_MEM //不是MEM／WB段数据相关
                        &&  R1_Pipeline_EXE != RD_Pipeline_WB; //不是MEM／WB段数据相关     
        Data_Dependency_3b = !Instruction_TYPE_Pipeline_WB[2] //不是I_TYPE_LOAD类指令  
                        &&  RD_Pipeline_WB != 0
                        &&  Instruction[24:20] == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R2Read //需要读取R2
                        &&  R2_Pipeline_EXE != RD_Pipeline_MEM //不是MEM／WB段数据相关
                        &&  R2_Pipeline_EXE != RD_Pipeline_WB; //不是MEM／WB段数据相关

        // load_use数据相关，在ID阶段检出
        Data_Dependency_load_use = Instruction_TYPE_Pipeline_EXE[2] // I_TYPE_LOAD类指令
                        &&  RD_Pipeline_EXE != 0  
                        &&  ((Instruction[19:15] == RD_Pipeline_EXE && R1Read) 
                              || (Instruction[24:20] == RD_Pipeline_EXE && R2Read));
        
        // 分支跳转条件为真
        Branch_COND_true =  Instruction_Pipeline_EXE[14:12] == 3'b000 && R1_Data_Selected == R2_Data_Selected || // B_beq
                            Instruction_Pipeline_EXE[14:12] == 3'b001 && R1_Data_Selected != R2_Data_Selected || // B_bne
                            Instruction_Pipeline_EXE[14:12] == 3'b100 && R1_Data_Selected < R2_Data_Selected  || // B_blt
                            Instruction_Pipeline_EXE[14:12] == 3'b101 && R1_Data_Selected > R2_Data_Selected  || // B_bge
                            Instruction_Pipeline_EXE[14:12] == 3'b110 && unsigned_R1_Data_Selected < unsigned_R2_Data_Selected || // B_bltu
                            Instruction_Pipeline_EXE[14:12] == 3'b111 && unsigned_R1_Data_Selected > unsigned_R2_Data_Selected;   // B_bgeu
        //检测Branch条件分支预测错误需要重新跳转或无条件I_jalr跳转，这两种情况都需要冲刷流水线
        //考虑到数据冒险，在EXE阶段检出
        PC_JUMP_EXECUTE = Instruction_TYPE_Pipeline_EXE[5] || (Instruction_TYPE_Pipeline_EXE[7] & (Branch_COND_true ^ Immediate_value_Pipeline_EXE[63]));
    end



    // == CPU reset =============================================================
    always @(posedge clk or negedge rstn) begin  
        if(!rstn) begin
            PC <= 64'h80000000;    
            Instruction_TYPE_Pipeline_WB <= 12'b0;
            Instruction_TYPE_Pipeline_MEM <= 12'b0;
            Instruction_TYPE_Pipeline_EXE <= 12'b0;
            RDWrite_Pipeline_WB <= 1'b0;
            RDWrite_Pipeline_MEM <= 1'b0;
            RDWrite_Pipeline_EXE <= 1'b0;
            R1Read_Pipeline_EXE <= 1'b0;
            R2Read_Pipeline_EXE <= 1'b0;
            Is32Bit_Pipeline_EXE <= 1'b0;
            ALU_OP_Pipeline_EXE <= 15'b0;
            ALU_X1_SRC_Pipeline_EXE <= 4'b0;
            ALU_X2_SRC_Pipeline_EXE <= 6'b0;
            Instruction_Pipeline_MEM <= 32'b0;
            Instruction_Pipeline_EXE <= 32'b0;
            Instruction <= 32'b0;
            PC_Pipeline_EXE <= 33'b0;
            PC_Pipeline_ID <= 33'b0;
            R1_Pipeline_EXE <= 5'b0;
            R2_Pipeline_EXE <= 5'b0;
            RD_Pipeline_WB <= 5'b0;
            RD_Pipeline_MEM <= 5'b0;
            RD_Pipeline_EXE <= 5'b0;
            R1_Data_Pipeline_EXE <= 64'b0;
            R2_Data_Pipeline_MEM <= 64'b0;
            R2_Data_Pipeline_EXE <= 64'b0;
            Immediate_value_Pipeline_EXE <= 64'b0;
            ALU_OUT_Pipeline_WB <= 64'b0;
            ALU_OUT_Pipeline_MEM <= 64'b0;
            Mem_r_Data_Pipeline_WB <= 64'b0;
            Instruction_temp <= 32'b0;

        end
        else begin
             //-----IF stage--------------------------------------------------------------
                //PC寄存器的更新
            if(pipeline_update) begin
                if(PC_JUMP_EXECUTE) begin
                    // 在EXECUTE阶段确定jalr和Branch的跳转地址
                    PC <= Instruction_TYPE_Pipeline_EXE[7]? 
                        {64{Branch_COND_true}} & (PC_Pipeline_EXE + Immediate_value_Pipeline_EXE) | // Branch分支预测错误不跳转
                        {64{!Branch_COND_true}} & (PC_Pipeline_EXE + 4) // Branch分支预测错误跳转
                        : {64{Instruction_TYPE_Pipeline_EXE[5]}} & ((R1_Data_Selected + Immediate_value_Pipeline_EXE) & 64'hfffffffffffffffe); // I_jalr
                end
                else if(JUMP_TYPE[0]) begin //在IF阶段minidecode，检测立即跳转指令J_jal
                    PC <= PC + Imm_JUMP;                     
                end 
                else if(JUMP_TYPE[1]) begin //在IF阶段minidecode，检测Branch指令
                    //如果立即数表示的偏移量为负数，意昧着方向为向后跳转，预测为需要跳转。
                    PC <= Imm_JUMP[63]? PC + Imm_JUMP: PC+4; 
                end
                else if(Data_Dependency_load_use) begin
                    //DECODE段检测到load_use相关时，PC 维持原值
                    PC <= PC;
                end
                else begin
                    PC <= PC + 4;
                end
            end

           if(Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6])
                if(I_Cache_ready)  
                    Instruction_temp <= Instruction_I_Cache;

                //IF/ID 流⽔线寄存器的更新
            if(pipeline_update) begin
                if(flush_ID) begin
                    Instruction     <= 0;  
                    PC_Pipeline_ID  <= 0;               
                end
                else begin
                    if(Data_Dependency_load_use) begin          
                        //DECODE段检测到load_use相关时，IF/ID 流⽔线寄存器维持原值        
                        PC_Pipeline_ID  <= PC_Pipeline_ID; 
                    end
                    else begin
                        PC_Pipeline_ID  <= PC;                   
                    end 
                end
            end


                //IF/ID 流⽔线寄存器的更新
            if(pipeline_update) begin
        
                if(flush_ID) begin
                    Instruction     <= 0;              
                end
                else begin
                    if(Data_Dependency_load_use) begin          
                        //DECODE段检测到load_use相关时，IF/ID 流⽔线寄存器维持原值        
                        Instruction <= Instruction; 
                    end
                    else begin
                        Instruction <= state? Instruction_temp: Instruction_I_Cache;     
                    end 
                end
            end
        
        //-----ID stage--------------------------------------------------------------   
            if(pipeline_update) begin
                //ID/EXE 流⽔线寄存器的更新
                //3a,3b数据相关解决方法：bypass
                R1_Data_Pipeline_EXE          <= flush_EXE? 0: Data_Dependency_3a? RD_WB_Data: R1_Data;
                R2_Data_Pipeline_EXE          <= flush_EXE? 0: Data_Dependency_3b? RD_WB_Data: R2_Data;
                //其他寄存器更新
                R1_Pipeline_EXE               <= flush_EXE? 0: R1;
                R2_Pipeline_EXE               <= flush_EXE? 0: R2;
                R1Read_Pipeline_EXE            <= flush_EXE? 0: R1Read;
                R2Read_Pipeline_EXE            <= flush_EXE? 0: R2Read;
                Is32Bit_Pipeline_EXE           <= flush_EXE? 0: Is32Bit;
                ALU_X1_SRC_Pipeline_EXE        <= flush_EXE? 0: ALU_X1_SRC;
                ALU_X2_SRC_Pipeline_EXE        <= flush_EXE? 0: ALU_X2_SRC;
                ALU_OP_Pipeline_EXE            <= flush_EXE? 0: ALU_OP;
                Instruction_TYPE_Pipeline_EXE <= flush_EXE? 0: Instruction_TYPE;   
                Instruction_Pipeline_EXE      <= flush_EXE? 0: Instruction;
                RDWrite_Pipeline_EXE          <= flush_EXE? 0: RDWrite;
                RD_Pipeline_EXE               <= flush_EXE? 0: RD;
                Immediate_value_Pipeline_EXE  <= flush_EXE? 0: Immediate_value;       
                PC_Pipeline_EXE               <= flush_EXE? 0: PC_Pipeline_ID;            
            end  

        //-----EXE stage---------------------------------------------------------------
            if(pipeline_update) begin
                //EXE/MEM 流⽔线寄存器的更新
                Instruction_TYPE_Pipeline_MEM <= Instruction_TYPE_Pipeline_EXE;   
                ALU_OUT_Pipeline_MEM          <= ALU_OUT;
                R2_Data_Pipeline_MEM          <= R2_Data_Selected;
                RDWrite_Pipeline_MEM          <= RDWrite_Pipeline_EXE;
                RD_Pipeline_MEM               <= RD_Pipeline_EXE;
                Instruction_Pipeline_MEM      <= Instruction_Pipeline_EXE;
            end 
        
        //-----MEM stage----------------------------------------------------------------
            if(pipeline_update) begin
                //MEM/WB 流⽔线寄存器的更新
                Instruction_Pipeline_WB      <= Instruction_Pipeline_MEM;
                ALU_OUT_Pipeline_WB          <= ALU_OUT_Pipeline_MEM;
                RD_Pipeline_WB               <= RD_Pipeline_MEM;
                RDWrite_Pipeline_WB          <= RDWrite_Pipeline_MEM;
                Mem_r_Data_Pipeline_WB       <= state && Instruction_TYPE_Pipeline_MEM[2]? 
                                                Mem_r_Data: Mem_r_Data_Pipeline_WB; // load指令从MEM读取数据   
                Instruction_TYPE_Pipeline_WB <= Instruction_TYPE_Pipeline_MEM;
            end  
        end
    end
    



    //-----IF stage--------------------------------------------------------------

    //mini_Decoder, 判断当前指令是否为jalr或Branch，并输出立即数
    mini_Decoder mini_Decoder((Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6])? Instruction_temp: Instruction_I_Cache,
                            pipeline_update, Imm_JUMP, JUMP_TYPE);

    //EXE级检测到I_jalr或者Branch分支预测跳转错误，需要冲刷EXE级和ID级流水线
    assign flush_ID = PC_JUMP_EXECUTE; 
    


    //-----ID stage--------------------------------------------------------------               
    //Decoder
    Decoder Decoder(Instruction, 
                    Immediate_value, 
                    Instruction_CODE, Instruction_TYPE, 
                    R1, R2, RD
                    );
    //RegFile
    RegFile  RegFile(.clk (clk),
                    .rstn(rstn),
                    .w_addr(RD_Pipeline_WB),
                    .w_data(RD_WB_Data),
                    .w_enable(RDWrite_Pipeline_WB),
                    .r_addr1(R1),
                    .r_addr2(R2),
                    .r_data1(R1_Data),
                    .r_data2(R2_Data)
                    );

    //Controller
    Controller Controller(Instruction_TYPE, Instruction_CODE, 
                          RDWrite, 
                          R1Read, R2Read, 
                          Is32Bit, ALU_OP, ALU_X1_SRC, ALU_X2_SRC
                          );
    
    //DECODE阶段检测到load use相关的下一个clock，给EXE插一个bubble
    //EXE阶段检测到I_jalr或者Branch分支预测跳转错误，需要冲刷EXE级和ID级流水线
    assign flush_EXE = Data_Dependency_load_use || PC_JUMP_EXECUTE; 


    

    //-----EXE stage---------------------------------------------------------------
    //1a,1b,2a,2b，以及load use插一个bubble后的数据相关冒险解决方法：数据前馈
    assign R1_Data_Selected = Data_Dependency_1a? ALU_OUT_Pipeline_MEM: 
                              Data_Dependency_2a? RD_WB_Data: R1_Data_Pipeline_EXE;

    assign R2_Data_Selected = Data_Dependency_1b? ALU_OUT_Pipeline_MEM: 
                              Data_Dependency_2b? RD_WB_Data: R2_Data_Pipeline_EXE;                         
    
    
    //ALU input selection
    assign ALU_X1 = {64{ALU_X1_SRC_Pipeline_EXE[0]}} & R1_Data_Selected |
                    {64{ALU_X1_SRC_Pipeline_EXE[1]}} & {{32{R1_Data_Selected[31]}}, R1_Data_Selected} |
                    {64{ALU_X1_SRC_Pipeline_EXE[2]}} & PC_Pipeline_EXE |
                    {64{ALU_X1_SRC_Pipeline_EXE[3]}} & 64'b0;

    assign ALU_X2 = {64{ALU_X2_SRC_Pipeline_EXE[0]}} & R2_Data_Selected |
                    {64{ALU_X2_SRC_Pipeline_EXE[1]}} & R2_Data_Selected[5:0] |
                    {64{ALU_X2_SRC_Pipeline_EXE[2]}} & R2_Data_Selected[4:0] |
                    {64{ALU_X2_SRC_Pipeline_EXE[3]}} & R2_Data_Selected[31:0] |
                    {64{ALU_X2_SRC_Pipeline_EXE[4]}} & Immediate_value_Pipeline_EXE |
                    {64{ALU_X2_SRC_Pipeline_EXE[5]}} & 64'd4;
    
    ALU ALU(ALU_X1, ALU_X2, Is32Bit_Pipeline_EXE, ALU_OP_Pipeline_EXE, ALU_OUT);


    
    //-----MEM stage----------------------------------------------------------------

    
    //-----WB stage-----------------------------------------------------------------
    //Write back Data selection
    assign RD_WB_Data = Instruction_TYPE_Pipeline_WB[2]? Mem_r_Data_Pipeline_WB: ALU_OUT_Pipeline_WB;        
endmodule

