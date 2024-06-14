`timescale 1ns / 1ps

/*
 * Top module
 */
module top (
    input  wire       clk,
    input  wire       rst,
//    input  wire       rx,       // UART RX
//    output reg        tx,       // UART TX
    inout  wire       sda,      // I2C data line
    inout  wire       scl,      // I2C clock line
    input  wire       write_enable,
    input  wire       read_enable,
	input  wire [7:0] word,     // Debug input word for FRAM
    output reg  [7:0] leds      // Debug LEDs
);

    reg start; // Start is set to high if write or read are high

    reg  [7:0] mem_address;    // 8-bit reg for word address (Needs to be 16-bit reg if FM24CLXX_TYPE > 2048)
    reg  [7:0] data_out;       // Data read (8 bits)
    reg        write_enable_reg;
    reg        read_enable_reg;

    // AXIS signals
    reg [6:0]  s_axis_cmd_address;
    reg        s_axis_cmd_start;
    reg        s_axis_cmd_read;
    reg        s_axis_cmd_write;
    reg        s_axis_cmd_write_multiple;
    reg        s_axis_cmd_stop;
    reg        s_axis_cmd_valid;
    wire       s_axis_cmd_ready;

    reg  [7:0] s_axis_data_tdata;
    reg        s_axis_data_tvalid;
    wire       s_axis_data_tready;
    reg        s_axis_data_tlast;

    wire [7:0] m_axis_data_tdata;
    wire       m_axis_data_tvalid;
    reg        m_axis_data_tready;
    wire       m_axis_data_tlast;

    // Tri-state buffer signals for SDA
    wire sda_i;
    wire sda_o;
    wire sda_t;

    // Tri-state buffer signals for SCL
    wire scl_i;
    wire scl_o;
    wire scl_t;

    wire i2c_busy;
    wire i2c_active;
    wire i2c_control;
    wire i2c_missed_ack;

    localparam FM24CLXX_TYPE = 2048;
    localparam FM24CLXX_ADDR = 3'b000;
    localparam TEST_MEM_ADDR = 8'h04;
    
    assign mem_address = TEST_MEM_ADDR;

    assign scl   = scl_t ? 1'bz : scl_o;
    assign scl_i = scl;
    assign sda   = sda_t ? 1'bz : sda_o;
    assign sda_i = sda;

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
		START,
		WAIT_ACK_START,
        WRITE_MEM_ADDR,
        WAIT_ACTION,
        WRITE_DATA,
        WAIT_ACK_WRITE_DATA,
        READ_DATA_REPEATED_START,
        WAIT_ACK_REPEATED_START,
        READ_DATA,
        WAIT_NACK_READ_DATA,
        STOP
    } state_t;

    state_t current_state = IDLE, next_state = IDLE;

    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
            write_enable_reg <= 1'b0;
            read_enable_reg  <= 1'b0;
            data_out <= 8'b0;
        end else begin
            if (current_state == IDLE) begin
                write_enable_reg <= write_enable;
                read_enable_reg  <= read_enable;
            end else if (current_state == STOP) begin
                write_enable_reg <= 1'b0;
                read_enable_reg  <= 1'b0;
            end else if (current_state == READ_DATA) begin
                if (m_axis_data_tvalid & i2c_active) begin
                    data_out <= m_axis_data_tdata;
                end
            end
            current_state <= next_state;
        end
    end
   
    assign start = write_enable_reg | read_enable_reg;

    always_comb begin
        // AXIL signals
        s_axis_cmd_address        = 7'b0;
        s_axis_cmd_start          = 1'b0;
        s_axis_cmd_write          = 1'b0;
        s_axis_cmd_read           = 1'b0;
        s_axis_cmd_write_multiple = 1'b0;
        s_axis_cmd_stop           = 1'b0;
        s_axis_cmd_valid          = 1'b0;

        s_axis_data_tdata         = 8'b0;
        s_axis_data_tvalid        = 1'b0;
        s_axis_data_tlast         = 1'b0;

        m_axis_data_tready        = 1'b0;
        
        // Next state of FSM
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start & ~i2c_busy) begin
                    next_state = START;
                end
            end
			START: begin
                // Start
                s_axis_cmd_address = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_valid = 1'b1;
                s_axis_cmd_write_multiple = 1'b1;
				if (s_axis_cmd_ready) begin
				    next_state = WAIT_ACK_START;
				end
			end
			WAIT_ACK_START: begin
			    if (~i2c_missed_ack) begin
                    next_state = WRITE_MEM_ADDR;
                end
            end
            WRITE_MEM_ADDR: begin
                // Send the memory address
                s_axis_data_tdata = mem_address;
                s_axis_data_tvalid = 1'b1;
                if (s_axis_data_tready & i2c_active) begin
                    next_state = WAIT_ACTION;
                end
            end
            WAIT_ACTION: begin
                if (write_enable_reg & ~i2c_missed_ack) begin
                    next_state = WRITE_DATA;
                end else if (read_enable_reg & ~i2c_missed_ack) begin
                    next_state = READ_DATA_REPEATED_START;
                end
            end
            WRITE_DATA: begin
                // Write data
                s_axis_data_tdata = word;
                s_axis_data_tvalid = 1'b1;
                s_axis_data_tlast = 1'b1;
                if (s_axis_data_tready & i2c_active) begin
                    next_state = WAIT_ACK_WRITE_DATA;
                end
            end
            WAIT_ACK_WRITE_DATA: begin
                if (~i2c_missed_ack) begin
                    next_state = STOP;
                end
            end
            READ_DATA_REPEATED_START: begin
                // Issue repeated start condition for read
                s_axis_cmd_address = {4'b1010, FM24CLXX_ADDR};;
                s_axis_cmd_read = 1'b1;
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready) begin
                    next_state = WAIT_ACK_REPEATED_START;
                end
            end
            WAIT_ACK_REPEATED_START: begin
                if (~i2c_missed_ack) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                // Read data
                m_axis_data_tready = 1'b1;
                if (m_axis_data_tvalid & i2c_active) begin
                    next_state = WAIT_NACK_READ_DATA;
                end
            end
            WAIT_NACK_READ_DATA: begin
                if (i2c_missed_ack) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                // Issue stop
                s_axis_cmd_address = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_stop = 1'b1;
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready & i2c_active) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    assign leds    = data_out;

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
        .busy(i2c_busy),
        .bus_control(i2c_control),
        .bus_active(i2c_active),
        .missed_ack(i2c_missed_ack),
        .prescale(16'd250),
        .stop_on_idle(1'b1)
    );
    
endmodule

