module RegFile(
    input  wire clk,
	input  wire rstn,
	
	input  wire  [4  : 0] w_addr,
	input  wire  [63 : 0] w_data,
	input  wire 		  w_enable,
	
	input  wire  [4  : 0] r_addr1,
	output reg   [63 : 0] r_data1,
	
	input  wire  [4  : 0] r_addr2,
	output reg   [63 : 0] r_data2
    );

    // 32 registers
	reg [63 : 0] 	regs[0 : 31];
	 
	always @(posedge clk or negedge rstn) 
	begin   
		if (!rstn) 
		begin: Reg_init
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 64'h0;
            end
		end
		else 
		begin
			if ((w_enable == 1'b1) && (w_addr != 5'h00)) //第0个寄存器通常被称为“零寄存器”，永远为0
				regs[w_addr] <= w_data;
		end
	end
	
	always @(*) begin
		if (!rstn)
			r_data1 = 64'h0;
		else
			r_data1 = regs[r_addr1];
	end
	
	always @(*) begin
		if (!rstn)
			r_data2 = 64'h0;
		else
			r_data2 = regs[r_addr2];
	end

endmodule
