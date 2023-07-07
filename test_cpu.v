
module test_cpu;

    reg clk; // posedge active
    reg rstn; // low active
    // connection: cpu <> main mamory
    wire        mode;
    wire        valid;
    wire        ready;
    wire [63:0] addr;
    wire [ 7:0] w_data;
    wire        r_data_valid;
    wire [ 7:0] r_data;
    wire        invalid_addr;
    wire        write_char_io;
    wire        simulation_stop;   

    initial begin
        $display("\n\n\nSimulation start......\n");
        clk = 0;
        rstn = 0;
        #20 rstn = 1; // release "reset" signal

        wait(simulation_stop == 1'b1);
        #10 $display("\n\nSimulation end.\n\n\n");
        $stop;
        // #10000;
        // $stop;
    end
    

    // creat clock
    initial begin
        forever #5 clk = ~clk;
    end

    // instantiate main memory
    main_memory main_memory_1(
    .clk(clk),
    .rstn(rstn),
    .mode(mode),
    .valid(valid),
    .ready(ready),
    .addr(addr),
    .w_data(w_data),
    .r_data_valid(r_data_valid),
    .r_data(r_data),
    .invalid_addr(invalid_addr),
    .write_char_io(write_char_io),
    .simulation_stop(simulation_stop)
);

    // instantiate CPU core
    CPU my_cpu(
    .clk(clk),
    .rstn(rstn),
    .mode(mode),
    .valid(valid),
    .ready(ready),
    .addr(addr),
    .w_data(w_data),
    .r_data_valid(r_data_valid),
    .r_data(r_data)
);

endmodule