module tb_top;

    // Parameters
    parameter CLK_PERIOD = 5;

    // Signals
    reg clk;
    reg rst;
    wire scl;
    wire sda;
    reg [7:0] leds;

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

        // Wait for global reset
        #(50*CLK_PERIOD);
        rst = 0;

        // Test write operation
        #(50*CLK_PERIOD);

        #(20*CLK_PERIOD);

        // Test read operation
        #(50*CLK_PERIOD);
        
        #(20*CLK_PERIOD);

        // Finish simulation
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("At time %t, leds = %b", 
                 $time, leds);
    end

endmodule
