`timescale 1ns / 1ps

/*
 * I2C master AXI lite wrapper
 */
module i2c_master_axil #
(
    parameter DEFAULT_PRESCALE = 1,
    parameter FIXED_PRESCALE = 0,
    parameter CMD_FIFO = 1,
    parameter CMD_FIFO_DEPTH = 32,
    parameter WRITE_FIFO = 1,
    parameter WRITE_FIFO_DEPTH = 32,
    parameter READ_FIFO = 1,
    parameter READ_FIFO_DEPTH = 32
)
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Host interface
     */
    input  wire [3:0]  s_axil_awaddr,
    input  wire [2:0]  s_axil_awprot,
    input  wire        s_axil_awvalid,
    output wire        s_axil_awready,
    input  wire [31:0] s_axil_wdata,
    input  wire [3:0]  s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output wire        s_axil_wready,
    output wire [1:0]  s_axil_bresp,
    output wire        s_axil_bvalid,
    input  wire        s_axil_bready,
    input  wire [3:0]  s_axil_araddr,
    input  wire [2:0]  s_axil_arprot,
    input  wire        s_axil_arvalid,
    output wire        s_axil_arready,
    output wire [31:0] s_axil_rdata,
    output wire [1:0]  s_axil_rresp,
    output wire        s_axil_rvalid,
    input  wire        s_axil_rready,

    /*
     * I2C interface
     */
    input  wire        i2c_scl_i,
    output wire        i2c_scl_o,
    output wire        i2c_scl_t,
    input  wire        i2c_sda_i,
    output wire        i2c_sda_o,
    output wire        i2c_sda_t
);

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [31:0] s_axil_rdata_reg = 32'd0, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg [6:0] cmd_address_reg = 7'd0, cmd_address_next;
reg cmd_start_reg = 1'b0, cmd_start_next;
reg cmd_read_reg = 1'b0, cmd_read_next;
reg cmd_write_reg = 1'b0, cmd_write_next;
reg cmd_write_multiple_reg = 1'b0, cmd_write_multiple_next;
reg cmd_stop_reg = 1'b0, cmd_stop_next;
reg cmd_valid_reg = 1'b0, cmd_valid_next;
wire cmd_ready;

reg [7:0] data_in_reg = 8'd0, data_in_next;
reg data_in_valid_reg = 1'b0, data_in_valid_next;
wire data_in_ready;
reg data_in_last_reg = 1'b0, data_in_last_next;

wire [7:0] data_out;
wire data_out_valid;
reg data_out_ready_reg = 1'b0, data_out_ready_next;
wire data_out_last;

reg [15:0] prescale_reg = DEFAULT_PRESCALE, prescale_next;

reg missed_ack_reg = 1'b0, missed_ack_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

wire [6:0] cmd_address_int;
wire cmd_start_int;
wire cmd_read_int;
wire cmd_write_int;
wire cmd_write_multiple_int;
wire cmd_stop_int;
wire cmd_valid_int;
wire cmd_ready_int;

wire [7:0] data_in_int;
wire data_in_valid_int;
wire data_in_ready_int;
wire data_in_last_int;

wire [7:0] data_out_int;
wire data_out_valid_int;
wire data_out_ready_int;
wire data_out_last_int;

wire busy_int;
wire bus_control_int;
wire bus_active_int;
wire missed_ack_int;

wire cmd_fifo_empty = !cmd_valid_int;
wire cmd_fifo_full = !cmd_ready;
wire write_fifo_empty = !data_in_valid_int;
wire write_fifo_full = !data_in_ready;
wire read_fifo_empty = !data_out_valid;
wire read_fifo_full = !data_out_ready_int;

reg cmd_fifo_overflow_reg = 1'b0, cmd_fifo_overflow_next;
reg write_fifo_overflow_reg = 1'b0, write_fifo_overflow_next;

generate

if (CMD_FIFO) begin
    axis_fifo #(
        .DEPTH(CMD_FIFO_DEPTH),
        .DATA_WIDTH(7+5),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    cmd_fifo_inst (
        .clk(clk),
        .rst(rst),
        // AXI input
        .s_axis_tdata({cmd_address_reg, cmd_start_reg, cmd_read_reg, cmd_write_reg, cmd_write_multiple_reg, cmd_stop_reg}),
        .s_axis_tkeep(0),
        .s_axis_tvalid(cmd_valid_reg),
        .s_axis_tready(cmd_ready),
        .s_axis_tlast(1'b0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(1'b0),
        // AXI output
        .m_axis_tdata({cmd_address_int, cmd_start_int, cmd_read_int, cmd_write_int, cmd_write_multiple_int, cmd_stop_int}),
        .m_axis_tkeep(),
        .m_axis_tvalid(cmd_valid_int),
        .m_axis_tready(cmd_ready_int),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser()
    );
end else begin
    assign cmd_address_int = cmd_address_reg;
    assign cmd_start_int = cmd_start_reg;
    assign cmd_read_int = cmd_read_reg;
    assign cmd_write_int = cmd_write_reg;
    assign cmd_write_multiple_int = cmd_write_multiple_reg;
    assign cmd_stop_int = cmd_stop_reg;
    assign cmd_valid_int = cmd_valid_reg;
    assign cmd_ready = cmd_ready_int;
end

if (WRITE_FIFO) begin
    axis_fifo #(
        .DEPTH(WRITE_FIFO_DEPTH),
        .DATA_WIDTH(8),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(1),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    write_fifo_inst (
        .clk(clk),
        .rst(rst),
        // AXI input
        .s_axis_tdata(data_in_reg),
        .s_axis_tkeep(0),
        .s_axis_tvalid(data_in_valid_reg),
        .s_axis_tready(data_in_ready),
        .s_axis_tlast(data_in_last_reg),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(1'b0),
        // AXI output
        .m_axis_tdata(data_in_int),
        .m_axis_tkeep(),
        .m_axis_tvalid(data_in_valid_int),
        .m_axis_tready(data_in_ready_int),
        .m_axis_tlast(data_in_last_int),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser()
    );
end else begin
    assign data_in_int = data_in_reg;
    assign data_in_valid = data_in_valid_reg;
    assign data_in_ready = data_in_ready_int;
    assign data_in_last = data_in_last_reg;
end

if (READ_FIFO) begin
    axis_fifo #(
        .DEPTH(READ_FIFO_DEPTH),
        .DATA_WIDTH(8),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(1),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    read_fifo_inst (
        .clk(clk),
        .rst(rst),
        // AXI input
        .s_axis_tdata(data_out_int),
        .s_axis_tkeep(0),
        .s_axis_tvalid(data_out_valid_int),
        .s_axis_tready(data_out_ready_int),
        .s_axis_tlast(data_out_last_int),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),
        // AXI output
        .m_axis_tdata(data_out),
        .m_axis_tkeep(),
        .m_axis_tvalid(data_out_valid),
        .m_axis_tready(data_out_ready_reg),
        .m_axis_tlast(data_out_last),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser()
    );
end else begin
    assign data_out = data_out_int;
    assign data_out_valid = data_out_valid_int;
    assign data_out_ready_int = data_out_ready_reg;
    assign data_out_last = data_out_last_int;
end

endgenerate

always @* begin
    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;
    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    cmd_address_next = cmd_address_reg;
    cmd_start_next = cmd_start_reg;
    cmd_read_next = cmd_read_reg;
    cmd_write_next = cmd_write_reg;
    cmd_write_multiple_next = cmd_write_multiple_reg;
    cmd_stop_next = cmd_stop_reg;
    cmd_valid_next = cmd_valid_reg && !cmd_ready;

    data_in_next = data_in_reg;
    data_in_valid_next = data_in_valid_reg && !data_in_ready;
    data_in_last_next = data_in_last_reg;

    data_out_ready_next = 1'b0;

    prescale_next = prescale_reg;

    missed_ack_next = missed_ack_reg || missed_ack_int;

    cmd_fifo_overflow_next = cmd_fifo_overflow_reg;
    write_fifo_overflow_next = write_fifo_overflow_reg;

    if (s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid) begin
        // write operation
        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        case ({s_axil_awaddr[3:2], 2'b00})
            4'h0: begin
                // status register
                if (s_axil_wstrb[0]) begin
                    if (s_axil_wdata[3]) begin
                        missed_ack_next = missed_ack_int;
                    end
                end
                if (s_axil_wstrb[1]) begin
                    if (s_axil_wdata[10]) begin
                        cmd_fifo_overflow_next = 1'b0;
                    end
                    if (s_axil_wdata[13]) begin
                        write_fifo_overflow_next = 1'b0;
                    end
                end
            end
            4'h4: begin
                // command
                if (s_axil_wstrb[0]) begin
                    cmd_address_next = s_axil_wdata[6:0];
                end
                if (s_axil_wstrb[1]) begin
                    cmd_start_next = s_axil_wdata[8];
                    cmd_read_next = s_axil_wdata[9];
                    cmd_write_next = s_axil_wdata[10];
                    cmd_write_multiple_next = s_axil_wdata[11];
                    cmd_stop_next = s_axil_wdata[12];
                    cmd_valid_next = cmd_start_next || cmd_read_next || cmd_write_next || cmd_write_multiple_next || cmd_stop_next;

                    cmd_fifo_overflow_next = cmd_fifo_overflow_next || (cmd_valid_next && !cmd_ready);
                end
            end
            4'h8: begin
                // data
                if (s_axil_wstrb[0]) begin
                    data_in_next = s_axil_wdata[7:0];

                    if (s_axil_wstrb[1]) begin
                        // only valid with atomic 16 bit write
                        data_in_last_next = s_axil_wdata[9];
                    end else begin
                        data_in_last_next = 1'b0;
                    end

                    data_in_valid_next = 1'b1;
                        
                    write_fifo_overflow_next = write_fifo_overflow_next || !data_in_ready;
                end
            end
            4'hC: begin
                // prescale
                if (!FIXED_PRESCALE && s_axil_wstrb[0]) begin
                    prescale_next[7:0] = s_axil_wdata[7:0];
                end
                if (!FIXED_PRESCALE && s_axil_wstrb[1]) begin
                    prescale_next[15:8] = s_axil_wdata[15:8];
                end
            end
        endcase
    end

    if (s_axil_arvalid && !s_axil_rvalid) begin
        // read operation
        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = 32'd0;

        case ({s_axil_araddr[3:2], 2'b00})
            4'h0: begin
                // status
                s_axil_rdata_next[0]  = busy_int;
                s_axil_rdata_next[1]  = bus_control_int;
                s_axil_rdata_next[2]  = bus_active_int;
                s_axil_rdata_next[3]  = missed_ack_reg;
                s_axil_rdata_next[4]  = 1'b0;
                s_axil_rdata_next[5]  = 1'b0;
                s_axil_rdata_next[6]  = 1'b0;
                s_axil_rdata_next[7]  = 1'b0;
                s_axil_rdata_next[8]  = cmd_fifo_empty;
                s_axil_rdata_next[9]  = cmd_fifo_full;
                s_axil_rdata_next[10] = cmd_fifo_overflow_reg;
                s_axil_rdata_next[11] = write_fifo_empty;
                s_axil_rdata_next[12] = write_fifo_full;
                s_axil_rdata_next[13] = write_fifo_overflow_reg;
                s_axil_rdata_next[14] = read_fifo_empty;
                s_axil_rdata_next[15] = read_fifo_full;
            end
            4'h4: begin
                // command
                s_axil_rdata_next[6:0] = cmd_address_reg;
                s_axil_rdata_next[7]  = 1'b0;
                s_axil_rdata_next[8]  = cmd_start_reg;
                s_axil_rdata_next[9]  = cmd_read_reg;
                s_axil_rdata_next[10] = cmd_write_reg;
                s_axil_rdata_next[11] = cmd_write_multiple_reg;
                s_axil_rdata_next[12] = cmd_stop_reg;
                s_axil_rdata_next[13] = 1'b0;
                s_axil_rdata_next[14] = 1'b0;
                s_axil_rdata_next[15] = 1'b0;
            end
            4'h8: begin
                // data
                s_axil_rdata_next[7:0] = data_out;
                s_axil_rdata_next[8] = data_out_valid;
                s_axil_rdata_next[9] = data_out_last;
                data_out_ready_next = data_out_valid;
            end
            4'hC: begin
                // prescale
                s_axil_rdata_next = prescale_reg;
            end
        endcase
    end
end

always @(posedge clk) begin
    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;
    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    cmd_address_reg <= cmd_address_next;
    cmd_start_reg <= cmd_start_next;
    cmd_read_reg <= cmd_read_next;
    cmd_write_reg <= cmd_write_next;
    cmd_write_multiple_reg <= cmd_write_multiple_next;
    cmd_stop_reg <= cmd_stop_next;
    cmd_valid_reg <= cmd_valid_next;

    data_in_reg <= data_in_next;
    data_in_valid_reg <= data_in_valid_next;
    data_in_last_reg <= data_in_last_next;

    data_out_ready_reg <= data_out_ready_next;

    prescale_reg <= prescale_next;

    missed_ack_reg <= missed_ack_next;

    cmd_fifo_overflow_reg <= cmd_fifo_overflow_next;
    write_fifo_overflow_reg <= write_fifo_overflow_next;

    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        cmd_valid_reg <= 1'b0;
        data_in_valid_reg <= 1'b0;
        data_out_ready_reg <= 1'b0;
        prescale_reg <= DEFAULT_PRESCALE;
        missed_ack_reg <= 1'b0;
        cmd_fifo_overflow_reg <= 1'b0;
        write_fifo_overflow_reg <= 1'b0;
    end
end

i2c_master
i2c_master_inst (
    .clk(clk),
    .rst(rst),

    // Host interface
    .s_axis_cmd_address(cmd_address_int),
    .s_axis_cmd_start(cmd_start_int),
    .s_axis_cmd_read(cmd_read_int),
    .s_axis_cmd_write(cmd_write_int),
    .s_axis_cmd_write_multiple(cmd_write_multiple_int),
    .s_axis_cmd_stop(cmd_stop_int),
    .s_axis_cmd_valid(cmd_valid_int),
    .s_axis_cmd_ready(cmd_ready_int),

    .s_axis_data_tdata(data_in_int),
    .s_axis_data_tvalid(data_in_valid_int),
    .s_axis_data_tready(data_in_ready_int),
    .s_axis_data_tlast(data_in_last_int),
    
    .m_axis_data_tdata(data_out_int),
    .m_axis_data_tvalid(data_out_valid_int),
    .m_axis_data_tready(data_out_ready_int),
    .m_axis_data_tlast(data_out_last_int),
    
    // I2C interface
    .scl_i(i2c_scl_i),
    .scl_o(i2c_scl_o),
    .scl_t(i2c_scl_t),
    .sda_i(i2c_sda_i),
    .sda_o(i2c_sda_o),
    .sda_t(i2c_sda_t),

    // Status
    .busy(busy_int),
    .bus_control(bus_control_int),
    .bus_active(bus_active_int),
    .missed_ack(missed_ack_int),

    // Configuration
    .prescale(prescale_reg),
    .stop_on_idle(1'b0)
);

endmodule
