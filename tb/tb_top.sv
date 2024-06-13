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

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  initial begin
    rst = 1;
    #20;
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
    .write(write),
    .read(read),
    .word(word),
    .leds(leds)
  );

  // Testbench stimulus
  initial begin
    @(negedge rst);

    // Wait for some time to ensure proper reset
    #100;

    fork
      send_ack_to_master();
      end_simulation();
    join_none

    write = 1;

    fork
      stop_condition_detected(write);
    join

    #100;
    
    read = 1;

    fork
      stop_condition_detected(read);
    join

    // Let everything end peacefully
    #100;

    // For now it will always fail :D
    assert (word == leds) else $error("ERROR: data mismatch");

  end

  // Monitor outputs
  initial begin
    $monitor("At time %t, leds = %b", $time, leds);
  end

  // Send ack to master every time there were 8 high sdas' and scls'
  task automatic send_ack_to_master();
    static int high_count = 0;
      forever @(posedge clk) begin
        if (sda && scl) begin
          high_count = high_count + 1;
            if (high_count == 8) begin
              @(negedge scl);  
              sda_t = 1'b0;
              sda_o = 1'b0;
              @(posedge scl);
              @(negedge scl);
              sda_t = 1'b1;
              sda_o = 1'bz;
              high_count = 0;
            end
        end
      end
  endtask

  // End simulation if there was 2 stop conditions
  task end_simulation();
    automatic int stop_condition_count = 0;
    automatic bit sda_prev = 0;
    forever @(posedge clk) begin
      if (scl && !sda_prev && sda) begin  // Stop condition
        stop_condition_count = stop_condition_count + 1;
        if (stop_condition_count == 2) begin
          $display("Two stop conditions detected at time %t. Ending simulation.", $time);
          $finish;
        end
      end
      sda_prev = sda;
    end
  endtask

  task automatic stop_condition_detected(ref reg rw);
    static bit sda_prev = 0;
    forever @(posedge clk) begin
      if (scl && !sda_prev && sda) begin
        rw = 0;
      end
      sda_prev = sda;
    end
  endtask
  
endmodule
