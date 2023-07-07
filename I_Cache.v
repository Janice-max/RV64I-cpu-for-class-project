module I_Cache (
    input           clk, rstn, 
    input  [31:0]   addr,        // 读写请求地址
    input           rd_req,      // 读请求信号
    input  [31:0]   wr_data,     // 要写入的数据，一次写一个word
    input           Inst_ready,  // 指令已经准备好
    output          cache_ready, // cache准备好
    output [31:0]   rd_data,      // 读出的数据，一次读一个word
    output          I_Cache_req_Mem     // 请求memory
);

    reg  [31:0] data  [0:15]; // 16个block, 每个block 32bit数据
    reg  [31:0] tag   [0:15]; // 16个block, 每个block 32bit tag
    reg         valid [0:15]; 
    reg         state, nxt_state;
    reg         hit;
    reg  [15:0] read_ptr;
    reg  [3:0]  write_ptr;
    reg  [3:0]  FIFO_depth;
    reg  [31:0] rd_data_buff;
    integer i;
    integer j;

    always @(posedge clk or negedge rstn) begin
        if(!rstn) state <= 1'b0;
        else state <= nxt_state;
    end

    always@(*) begin
        case(state)
        1'b0: //收到读请求
            if(rd_req) nxt_state = 1'b1;
            else nxt_state = 1'b0;
        1'b1: //如果命中，返回数据，否则拉高写请求状态, 直到向memory请求到新的指令才返回
            if(hit) nxt_state = 1'b0;
            else if(Inst_ready) nxt_state = 1'b0;
            else nxt_state = 1'b1;
        endcase
    end

    always@(*) begin
            for(i=0; i<16; i=i+1) begin
                read_ptr[i] = valid[i] && (tag[i] == addr);
            end        
            hit = state && read_ptr;                         
    end

    always@(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(j=0; j<16; j=j+1) begin
               data[j] <= 0;
               tag[j] <= 0;
               valid[j] <= 0;
            end                    
            write_ptr <= 0;
            rd_data_buff <= 0;
            FIFO_depth <= 0;
        end
        else begin         
            if(!state & rd_req) begin            
                rd_data_buff <=  data[0] & {32{read_ptr[0]}} |
                            data[1] & {32{read_ptr[1]}} |
                            data[2] & {32{read_ptr[2]}} |
                            data[3] & {32{read_ptr[3]}} |
                            data[4] & {32{read_ptr[4]}} |
                            data[5] & {32{read_ptr[5]}} |
                            data[6] & {32{read_ptr[6]}} |   
                            data[7] & {32{read_ptr[7]}} |
                            data[8] & {32{read_ptr[8]}} |
                            data[9] & {32{read_ptr[9]}} |
                            data[10] & {32{read_ptr[10]}} |
                            data[11] & {32{read_ptr[11]}} |
                            data[12] & {32{read_ptr[12]}} |
                            data[13] & {32{read_ptr[13]}} |
                            data[14] & {32{read_ptr[14]}} |
                            data[15] & {32{read_ptr[15]}} ;
            end
            else if(state) begin      
                if(!hit && Inst_ready) begin
                    if(FIFO_depth == 4'b1111) begin
                        write_ptr <= (write_ptr == 4'b1111)? 4'b0: write_ptr + 1;
                        data[write_ptr] <= wr_data;
                        valid[write_ptr] <= 1;
                        tag[write_ptr] <= addr;
                    end
                    else begin
                        FIFO_depth <= FIFO_depth + 1;    
                        data[FIFO_depth] <= wr_data;
                        valid[FIFO_depth] <= 1;
                        tag[FIFO_depth] <= addr;
                    end
                end
            end
        end
    end

    assign cache_ready = state & (!nxt_state);
    assign rd_data = hit? rd_data_buff: {32{state & !nxt_state}} & wr_data;
    assign I_Cache_req_Mem = state && !hit;
endmodule

