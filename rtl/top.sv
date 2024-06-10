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
    // Needs to be 16-bit reg if FM24CLXX_TYPE > 2048
    reg  [7:0]  mem_address;    // 8-bit reg for word address
    reg  [7:0]  data_in;        // Data to write (32 bits)
    wire [7:0]  data_out;       // Data read (32 bits)
    reg         write_enable;   // Write operation enable
    reg         read_enable;    // Read operation enable

    // AXIS signals
    wire [6:0]  s_axis_cmd_address;
    wire        s_axis_cmd_start;
    wire        s_axis_cmd_read;
    wire        s_axis_cmd_write;
    wire        s_axis_cmd_write_multiple;
    wire        s_axis_cmd_stop;
    wire        s_axis_cmd_valid;
    wire        s_axis_cmd_ready;

    wire [7:0]  s_axis_data_tdata;
    wire        s_axis_data_tvalid;
    wire        s_axis_data_tready;
    wire        s_axis_data_tlast;

    wire [7:0]  m_axis_data_tdata;
    wire        m_axis_data_tvalid;
    wire        m_axis_data_tready;
    wire        m_axis_data_tlast;

    // Internal signal to hold read data for comparison
    reg [7:0] read_data;
    
    // Tri-state buffer signals for SDA
    wire sda_i;
    wire sda_o;
    wire sda_t;

    // Tri-state buffer signals for SCL
    wire scl_i;
    wire scl_o;
    wire scl_t;

    // Instantiate axil_master
    axis_master #(
        .FM24CLXX_TYPE(2048),
        .FM24CLXX_ADDR(3'b000)
    ) axis (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mem_address(mem_address),
        .data_in(data_in),
        .data_out(data_out),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .busy(busy),
        .s_axis_cmd_address(s_axis_cmd_address),
        .s_axis_cmd_start(s_axis_cmd_start),
        .s_axis_cmd_read(s_axis_cmd_read),
        .s_axis_cmd_write(s_axis_cmd_write),
        .s_axis_cmd_write_multiple(s_axis_cmd_write_multiple),
        .s_axis_cmd_stop(s_axis_cmd_stop),
        .s_axis_cmd_valid(s_axis_cmd_valid),
        .s_axis_cmd_ready(s_axis_cmd_ready),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        .s_axis_data_tlast(s_axis_data_tlast),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_data_tready(m_axis_data_tready),
        .m_axis_data_tlast(m_axis_data_tlast)
    );

    // Instantiate i2c_master_axil
    i2c_master i2c (
        .clk(clk),
        .rst(rst),
        .s_axis_cmd_address(s_axis_cmd_address),
        .s_axis_cmd_start(s_axis_cmd_start),
        .s_axis_cmd_read(s_axis_cmd_read),
        .s_axis_cmd_write(s_axis_cmd_write),
        .s_axis_cmd_write_multiple(s_axis_cmd_write_multiple),
        .s_axis_cmd_stop(s_axis_cmd_stop),
        .s_axis_cmd_valid(s_axis_cmd_valid),
        .s_axis_cmd_ready(s_axis_cmd_ready),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        .s_axis_data_tlast(s_axis_data_tlast),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_data_tready(m_axis_data_tready),
        .m_axis_data_tlast(m_axis_data_tlast),
        .scl_i(scl_i),
        .scl_o(scl_o),
        .scl_t(scl_t),
        .sda_i(sda_i),
        .sda_o(sda_o),
        .sda_t(sda_t),
        .busy(),
        .bus_control(),
        .bus_active(),
        .missed_ack(),
        .prescale(16'd49),
        .stop_on_idle(1'b1)
    );

    assign scl = scl_t ? 1'bz : scl_o;
    assign scl_i = scl;
    assign sda = sda_t ? 1'bz : sda_o;
    assign sda_i = sda;

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
            test_state <= IDLE;
            leds <= 8'b0000_0000;
            start <= 0;
            write_enable <= 0;
            read_enable <= 0;
            mem_address <= 8'h00;
            data_in <= 32'h00000000;
         end else begin
            case (test_state)
                IDLE: begin
                   mem_address <= 8'h04;
                   data_in <= 32'h000000A5;
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
                    if (~busy) begin
                        leds <= 8'b0000_0111;
                        test_state <= READ;
                    end
                end
                READ: begin
                    write_enable <= 0;
                    leds <= 8'b0000_1111;
                    read_enable <= 1;
                    if (~busy) begin
                        leds <= 8'b0001_1111;
                        test_state <= CHECK_READ;
                    end
                end
                CHECK_READ: begin
                    leds <= 8'b0011_1111;
                    read_enable <= 0;
                    if (data_in[7:0] == data_out[7:0]) begin
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

