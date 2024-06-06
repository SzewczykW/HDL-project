`timescale 1ns / 1ps

/*
 * Testbench for i2c_master based on myhdl
 */
module test_i2c_master;

// Parameters

// Inputs
logic clk = 0;
logic rst = 0;
logic [7:0] current_test = 0;

logic [6:0] s_axis_cmd_address = 0;
logic s_axis_cmd_start = 0;
logic s_axis_cmd_read = 0;
logic s_axis_cmd_write = 0;
logic s_axis_cmd_write_multiple = 0;
logic s_axis_cmd_stop = 0;
logic s_axis_cmd_valid = 0;
logic [7:0] s_axis_data_tdata = 0;
logic s_axis_data_tvalid = 0;
logic s_axis_data_tlast = 0;
logic m_axis_data_tready = 0;
logic scl_i = 1;
logic sda_i = 1;
logic [15:0] prescale = 0;
logic stop_on_idle = 0;

// Outputs
logic s_axis_cmd_ready;
logic s_axis_data_tready;
logic [7:0] m_axis_data_tdata;
logic m_axis_data_tvalid;
logic m_axis_data_tlast;
logic scl_o;
logic scl_t;
logic sda_o;
logic sda_t;
logic busy;
logic bus_control;
logic bus_active;
logic missed_ack;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_cmd_address,
        s_axis_cmd_start,
        s_axis_cmd_read,
        s_axis_cmd_write,
        s_axis_cmd_write_multiple,
        s_axis_cmd_stop,
        s_axis_cmd_valid,
        s_axis_data_tdata,
        s_axis_data_tvalid,
        s_axis_data_tlast,
        m_axis_data_tready,
        scl_i,
        sda_i,
        prescale,
        stop_on_idle
    );
    $to_myhdl(
        s_axis_cmd_ready,
        s_axis_data_tready,
        m_axis_data_tdata,
        m_axis_data_tvalid,
        m_axis_data_tlast,
        scl_o,
        scl_t,
        sda_o,
        sda_t,
        busy,
        bus_control,
        bus_active,
        missed_ack
    );

    // dump file
    $dumpfile("test_i2c_master.lxt");
    $dumpvars(0, test_i2c_master);
end

i2c_master
UUT (
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
    .busy(busy),
    .bus_control(bus_control),
    .bus_active(bus_active),
    .missed_ack(missed_ack),
    .prescale(prescale),
    .stop_on_idle(stop_on_idle)
);

endmodule
