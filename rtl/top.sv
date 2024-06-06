`timescale 1ns / 1ps

/*
 * Top module
 */
module top (
    input wire clk,
    input wire rst,
    inout wire sda,     // I2C data line
    inout wire scl,     // I2C clock line
    output reg [7:0] leds // Debug LEDs
);

    // Internal signals for AXI master and I2C communication
    reg start;
    reg [10:0] mem_address;  // 11-bit address for 2KB memory
    reg [31:0] data_in;      // Data to write (32 bits)
    wire [31:0] data_out;    // Data read (32 bits)
    reg write_enable;        // Write operation enable
    reg read_enable;         // Read operation enable

    // AXI4Lite signals
    wire [3:0] s_axil_awaddr;
    wire s_axil_awvalid;
    wire s_axil_awready;
    wire [31:0] s_axil_wdata;
    wire [3:0] s_axil_wstrb;
    wire s_axil_wvalid;
    wire s_axil_wready;
    wire [1:0] s_axil_bresp;
    wire s_axil_bvalid;
    wire s_axil_bready;
    wire [3:0] s_axil_araddr;
    wire s_axil_arvalid;
    wire s_axil_arready;
    wire [31:0] s_axil_rdata;
    wire [1:0] s_axil_rresp;
    wire s_axil_rvalid;
    wire s_axil_rready;

    // Internal signal to hold read data for comparison
    reg [31:0] read_data;
    
    // Tri-state buffer signals for SDA
    wire sda_i;
    wire sda_o;
    wire sda_t;

    // Tri-state buffer signals for SCL
    wire scl_i;
    wire scl_o;
    wire scl_t;

    // Instantiate axil_master
    axil_master #(
        .FM24CLXX_TYPE(2048),
        .FM24CLXX_ADDR(3'b000)
    ) axil (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mem_address(mem_address),
        .data_in(data_in),
        .data_out(data_out),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .busy(busy),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready)
    );

    // Instantiate i2c_master_axil
    i2c_master_axil i2c (
        .clk(clk),
        .rst(rst),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .i2c_scl_i(scl_i),
        .i2c_scl_o(scl_o),
        .i2c_scl_t(scl_t),
        .i2c_sda_i(sda_i),
        .i2c_sda_o(sda_o),
        .i2c_sda_t(sda_t)
    );

    // Tri-state buffer for SDA
    assign sda = sda_t ? 1'bz : sda_o;
    assign sda_i = sda;

    // Tri-state buffer for SCL
    assign scl = scl_t ? 1'bz : scl_o;
    assign scl_i = scl;

    // Initialize internal signals for testing
    typedef enum logic [2:0] {
        IDLE,
        START,
        WRITE,
        READ,
        CHECK_READ,
        DONE
    } test_states;
    
    test_states test_state = IDLE;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            test_state <= START;
            leds <= 8'b0000_0000;
            start <= 0;
            write_enable <= 0;
            read_enable <= 0;
         end else begin
            case (test_state)
                IDLE: begin
                   mem_address <= 11'h005;
                   data_in <= 32'hA5A5A5A5;
                   test_state <= START;
                end
                START: begin
                    start <= 1;
                    test_state <= WRITE;
                    leds <= 8'b0000_0001;
                end
                WRITE: begin
                    leds <= 8'b0000_0011;
                    write_enable <= 1;
                    if (s_axil_bvalid == 1) begin
                        leds <= 8'b0000_0111;
                        write_enable <= 0;
                        test_state <= READ;
                    end
                end
                READ: begin
                    leds <= 8'b0000_1111;
                    read_enable <= 1;
                    if (s_axil_rvalid == 1) begin
                        leds <= 8'b0001_1111;
                        read_enable <= 0;
                        test_state <= CHECK_READ;
                    end
                end
                CHECK_READ: begin
                    leds <= 8'b0011_1111;
                    if (data_in == data_out) begin
                        leds <= 8'b0111_1111;
                        test_state <= DONE;
                    end
                end
                DONE: begin
                    leds <= 8'b1111_1111;
                end
            endcase
         end
     end
endmodule

