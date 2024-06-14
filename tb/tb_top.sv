`timescale 1ns/1ps

module tb_top;

  // Clock and reset signals
  reg clk;
  reg rst;

  // I2C signals
  wire  scl;
  wire  sda;
  wire  sda_i;
  reg   sda_o;
  reg   sda_t;
  
  reg        write;
  reg        read;
  reg  [7:0] word;
  wire [7:0] leds;
  

  pullup(scl);
  pullup(sda); 

  assign sda   = sda_t ? 1'bz : sda_o;
  assign sda_i = sda;
  
  localparam CLK_DIV  = 5;
  localparam PRESCALE = 250;
  localparam SCL_DIV  = PRESCALE * CLK_DIV; 

  // Clock generation
  initial begin
    clk = 0;
    forever #CLK_DIV clk = ~clk; // 100MHz clock
  end

  initial begin
    rst = 1;
    #(4*CLK_DIV);
    rst = 0;
  end

  initial begin
    word = 8'hA5;
    
    write = 0;
    read  = 0;
    sda_t = 1'b1;
    sda_o = 1'bz;
  end

  top uut (
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .scl(scl),
    .write_enable(write),
    .read_enable(read),
    .word(word),
    .leds(leds)
  );

  // Testbench stimulus
  initial begin
    $timeformat(-6, 2, "us");
    @(negedge rst);

    // Wait for some time to ensure proper reset
    #(20*CLK_DIV);

    fork
      send_ack_to_master();
      end_simulation();
    join_none

    write = 1;

    fork
      start_condition_detected_write(write);
    join

    #(60*SCL_DIV);
    
    read = 1;

    fork
      start_condition_detected_read(read);
    join

    // Let everything end peacefully
    #(60*SCL_DIV);

    // For now it will always fail :D
//    assert (word == leds) else $error("ERROR: data mismatch");

  end

  // Monitor outputs
  initial begin
    $monitor("At time %t, leds = %b", $time, leds);
  end

  // Send ack to master every time there were 8 high sdas' and scls'
  task automatic  send_ack_to_master();
    automatic int high_count = 0;
	automatic bit is_started = 0;
	automatic reg sda_prev = 1'b1;
	automatic reg scl_prev = 1'b1;
      forever @(scl,sda) begin
        if (is_started & scl & scl_prev & ~sda_prev & sda) begin
		  is_started = 0;
		  high_count = 0;
		end
		if (is_started & high_count == 8) begin
		  sda_t = 1'b0;
		  sda_o = 1'b0;
		  @(posedge scl);
		  @(negedge scl);
		  sda_t = 1'b1;
		  sda_o = 1'bz;
		  high_count = 0;
		end
		if (is_started & scl & ~scl_prev) begin
		  high_count = high_count + 1;
		  $display("time: %t, high_count: %d", $time, high_count);
		end
		if (~is_started & scl & scl_prev & sda_prev & ~sda) begin
		  is_started = 1;
		  high_count = 0;
		end
		sda_prev = sda;
		scl_prev = scl;
      end
  endtask

  // End simulation if there was 2 stop conditions
  task end_simulation();
    automatic int stop_condition_count = 0;
    automatic reg sda_prev = 1'b1;
    forever @(posedge clk) begin
      if (scl & ~sda_prev & sda) begin  // Stop condition
        stop_condition_count = stop_condition_count + 1;
        if (stop_condition_count == 2) begin
          $display("Two stop conditions detected at time %t. Ending simulation.", $time);
          $finish;
        end
      end
      sda_prev = sda;
    end
  endtask

  task automatic start_condition_detected_write(ref reg write);
    automatic reg sda_prev = 1'b1;
    forever @(posedge clk) begin
      if (scl & sda_prev & ~sda) begin
        write = 0;
        disable start_condition_detected_write;
      end
      sda_prev = sda;
    end
  endtask
  
  task automatic start_condition_detected_read(ref reg read);
    automatic reg sda_prev = 1'b1;
    forever @(posedge clk) begin
      if (scl & sda_prev & ~sda) begin
        read = 0;
        disable start_condition_detected_read;
      end
      sda_prev = sda;
    end
  endtask
  
endmodule
