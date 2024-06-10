`timescale 1ns/1ps

module tb_top;

  // Clock and reset signals
  reg clk;
  reg rst;

  // I2C signals
  reg scl_reg;
  wire scl;
  reg sda_out;
  wire sda;
  assign sda = sda_out; // Tri-state SDA line for I2C communication
  assign scl = scl_reg;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  initial begin
    scl_reg = 1;
    forever #40000 scl_reg = ~scl_reg; // 12.5kHz clock for I2C
  end

  initial begin
    rst = 1;
    sda_out = 1;
    #20;
    rst = 0;
  end

  wire [7:0] leds;
  top u_top (
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .scl(scl),
    .leds(leds)
  );

  // Testbench stimulus
  initial begin
    @(negedge rst);

    // Wait for some time to ensure proper reset
    #100;

    // Simulate I2C slave responses
    fork
      begin: i2c_slave
        i2c_wait_start();
        i2c_receive_address();
        i2c_ack(); // ACK address
        i2c_receive_data();
        i2c_ack(); // ACK data
        i2c_receive_data();
        i2c_ack(); // ACK data
        i2c_wait_start();
        i2c_receive_address();
        i2c_ack(); // ACK address
        i2c_send_data(8'h55);
        i2c_ack(); // ACK read data
      end
    join

    // End of simulation
    #1000;
    $finish;
  end

  // I2C tasks
  task i2c_wait_start();
    begin
      wait (scl && !sda); // Wait for start condition
    end
  endtask

  task i2c_receive_address();
    integer i;
    reg [7:0] address;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        wait (!scl); // Wait for SCL to be low
        address[i] = sda;
        wait (scl); // Wait for SCL to be high
      end
      $display("Received address: %h", address);
    end
  endtask

  task i2c_receive_data();
    integer i;
    reg [7:0] data;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        wait (!scl); // Wait for SCL to be low
        data[i] = sda;
        wait (scl); // Wait for SCL to be high
      end
      $display("Received data: %h", data);
    end
  endtask

  task i2c_send_data(input [7:0] data);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        sda_out = data[i];
        wait (!scl); // Wait for SCL to be low
        wait (scl); // Wait for SCL to be high
      end
      sda_out = 1; // Release SDA after data transmission
      $display("Sent data: %h", data);
    end
  endtask

  task i2c_ack();
    begin
      sda_out = 0; // Send ACK
      #20000;
      scl_reg = 1;
      #40000;
      scl_reg = 0;
      #20000;
      sda_out = 1; // Release SDA
    end
  endtask

  // Monitor outputs
  initial begin
    $monitor("At time %t, leds = %b", $time, leds);
  end

endmodule