`timescale 1ns / 1ps

module tb_top;

    // Parameters
    parameter CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst;
    wire scl;
    wire sda;
    reg start;
    reg [10:0] mem_address;
    reg [31:0] data_in;
    reg write_enable;
    reg read_enable;
    wire [31:0] data_out;
    wire busy;
    reg [4:0] leds;

    // Instantiate the top module
    top uut (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda(sda),
        .leds(leds)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        rst = 1;
        start = 0;
        mem_address = 11'd0;
        data_in = 8'd0;
        write_enable = 0;
        read_enable = 0;

        // Wait for global reset
        #(2*CLK_PERIOD);
        rst = 0;

        // Test write operation
        #CLK_PERIOD;
        start = 1;
        mem_address = 11'h005;
        data_in = 8'hA5A5A5A5;
        write_enable = 1;
        read_enable = 0;
        #CLK_PERIOD;
        start = 0;

        // Wait some time for write to complete
        #(20*CLK_PERIOD);

        // Test read operation
        #CLK_PERIOD;
        start = 1;
        mem_address = 11'h005;
        write_enable = 0;
        read_enable = 1;
        #CLK_PERIOD;
        start = 0;

        // Wait some time for read to complete
        #(20*CLK_PERIOD);

        // Finish simulation
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("At time %t, leds = %b, busy = %b, data_out = %h", 
                 $time, leds, busy, data_out);
    end

endmodule
