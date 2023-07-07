module memory_access_ctrl(
    input wire clk,
    input wire rstn,

    // with cpu
    input wire              r_mem_ena, //CPU发出读memory请求
    input wire              w_mem_ena, //CPU发出写memory请求
    input wire  [64-1 : 0]  rw_mem_addr,
    input wire  [   2 : 0]  rw_mem_bytes,
    input wire  [64-1 : 0]  w_mem_data,

    output wire             mem_data_ready,
    output wire [64-1 : 0]  mem_data,

    //with main memory
    output          mode, // mode=0 -> read; mode -> 1 write;
    output          valid,
    input           ready,
    output  [63:0]  addr,
    output  [ 7:0]  w_data,
    input           r_data_valid,
    input [ 7:0]    r_data
);

    // State register
    reg [2:0] state, nxt_state;

    reg [ 2 : 0] rw_mem_bytes_buff;
    reg [63 : 0] rw_mem_addr_buff;
    reg [63 : 0] w_mem_data_buf;

    reg [63 : 0] mem_data_buff;
    reg [ 3 : 0] mem_data_byte_count;
    reg [ 3 : 0] mem_data_byte_fix;

    reg [ 2 : 0] load_inst;


    always @(posedge clk or negedge rstn) begin
        if(!rstn) state <= 3'd0;
        else state <= nxt_state;
    end

    always@(*) case(state)
        3'd0: begin
            if(r_mem_ena) nxt_state = 3'd1;     
            else if(w_mem_ena) nxt_state = 3'd2;
            else nxt_state = 3'd0;
        end
        3'd1: begin //处理cpu读memory请求，直到读取完成跳出该状态
            if(ready && rw_mem_bytes_buff == 0 ) nxt_state = 3'd3;
            else nxt_state = 3'd1;
        end
        3'd2: begin //处理cpu写memory请求，直到写完成跳出该状态
            if(ready && rw_mem_bytes_buff == 0) nxt_state = 3'd0;
            else nxt_state = 3'd2;
        end
        3'd3: begin //cpu读取memory
            if(mem_data_byte_count == mem_data_byte_fix) nxt_state = 3'd0;
            else nxt_state = 3'd3;
        end
    endcase

    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            rw_mem_bytes_buff <= 3'b0;
            rw_mem_addr_buff <= 64'b0;
            w_mem_data_buf <= 64'b0;
            load_inst <= 3'b0;
        end
        else if(state == 0 && (r_mem_ena || w_mem_ena)) begin
            if(rw_mem_bytes[1:0] == 2'b00) rw_mem_bytes_buff <= 3'd0;
            else if(rw_mem_bytes[1:0] == 2'b01) rw_mem_bytes_buff <= 3'd1;
            else if(rw_mem_bytes[1:0] == 2'b10) rw_mem_bytes_buff <= 3'd3;
            else if(rw_mem_bytes[1:0] == 2'b11) rw_mem_bytes_buff <= 3'd7;
            rw_mem_addr_buff <= rw_mem_addr;
            w_mem_data_buf <= w_mem_data;
            load_inst <= rw_mem_bytes;
        end
        else if(state == 1) begin
            if(ready) begin //读取memory数据
                rw_mem_bytes_buff <= rw_mem_bytes_buff - 3'b1;
                rw_mem_addr_buff <= rw_mem_addr_buff + 64'b1;
            end
        end
        else if (state == 2) begin
            if(ready) begin //写入memory数据
                rw_mem_bytes_buff <= rw_mem_bytes_buff - 3'b1;
                rw_mem_addr_buff <= rw_mem_addr_buff + 64'b1;
            end
        end
    end

    // port <> cpu
    
    always @(posedge clk or negedge rstn) begin
        if(!rstn) mem_data_byte_fix <= 4'b0;
        else if(state == 0 && (r_mem_ena)) begin
            if(rw_mem_bytes[1:0] == 2'b00) mem_data_byte_fix <= 4'd1;
            else if(rw_mem_bytes[1:0] == 2'b01) mem_data_byte_fix <= 4'd2;
            else if(rw_mem_bytes[1:0] == 2'b10) mem_data_byte_fix <= 4'd4;
            else if(rw_mem_bytes[1:0] == 2'b11) mem_data_byte_fix <= 4'd8;
        end 
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn) mem_data_byte_count <= 4'b0;
        else if(state == 0 && (r_mem_ena)) mem_data_byte_count <= 4'd0;
        else if(r_data_valid) mem_data_byte_count <= mem_data_byte_count + 3'd1;
    end

    always @(posedge clk or negedge rstn) begin
        if(!rstn) mem_data_buff <= 64'b0;
        else if(state == 0) mem_data_buff <= 64'b0;
        else if(state == 1 || state == 3) begin
            // case(mem_data_byte_count[2:0])

            // endcase
            if(r_data_valid) mem_data_buff[mem_data_byte_count[2:0]*8 +: 8] <= r_data;
        end
    end

    assign mem_data_ready = (state == 3 && mem_data_byte_count == mem_data_byte_fix) | //读取memory数据完成
                            (state == 2 && nxt_state == 0); //写入memory数据完成
    assign mem_data = mem_data_buff;

    // port <> main memory
    reg [63:0] sign_ext_w_mem_data;
    always @(*) begin
        case(load_inst)
            3'b000: sign_ext_w_mem_data = {{(64- 8){1'b0}}, w_mem_data_buf[ 7:0]};
            3'b001: sign_ext_w_mem_data = {{(64-16){1'b0}}, w_mem_data_buf[15:0]};
            3'b010: sign_ext_w_mem_data = {{(64-32){1'b0}}, w_mem_data_buf[31:0]};
            3'b011: sign_ext_w_mem_data =              w_mem_data_buf[63:0];
            3'b100: sign_ext_w_mem_data = {{(64- 8){w_mem_data_buf[ 7]}}, w_mem_data_buf[ 7:0]};
            3'b101: sign_ext_w_mem_data = {{(64-16){w_mem_data_buf[15]}}, w_mem_data_buf[15:0]};
            3'b110: sign_ext_w_mem_data = {{(64-32){w_mem_data_buf[31]}}, w_mem_data_buf[31:0]};
            3'b111: sign_ext_w_mem_data =                                 w_mem_data_buf[ 63:0];
        endcase
    end  

    wire [2:0] byte_count_bias;

    assign byte_count_bias =    {3{load_inst[1:0] == 2'b00}} & 3'd0 |
                                {3{load_inst[1:0] == 2'b01}} & 3'd1 |
                                {3{load_inst[1:0] == 2'b10}} & 3'd3 |
                                {3{load_inst[1:0] == 2'b11}} & 3'd7 ;
    wire [2:0] diff_byte_count_bias = byte_count_bias - rw_mem_bytes_buff;
    

    assign mode =   (state == 1) & 1'b0 | 
                    (state == 2) & 1'b1 ;
    assign valid = state == 1 || state == 2;
    assign addr = rw_mem_addr_buff;
    assign w_data = sign_ext_w_mem_data[diff_byte_count_bias*8 +: 8];


endmodule
