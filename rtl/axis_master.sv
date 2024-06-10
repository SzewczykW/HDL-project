`timescale 1ns / 1ps

/*
 * AXI4Lite Master module for FM24CL16B FRAM
 */
module axis_master #(
    parameter FM24CLXX_TYPE = 2048,  // Memory size in bytes
    parameter FM24CLXX_ADDR = 3'b000 // I2C address pins
) (
    input wire        clk,
    input wire        rst,
    input wire        start,
    // Needs to be 16-bit reg if FM24CLXX_TYPE > 2048
    input wire [7:0]  mem_address,         // 8-bit word address register
    input wire [7:0]  data_in,             // Data to write
    output reg [7:0]  data_out,            // Data read
//    input wire       read_write_word_size // Size of word to be read or write
    input wire        write_enable,        // Write operation enable
    input wire        read_enable,         // Read operation enable
    output reg        busy,                // Driver busy signal

    // AXIS Interface signals to connect to I2C master
    output reg [6:0]  s_axis_cmd_address,
    output reg        s_axis_cmd_start,
    output reg        s_axis_cmd_read,
    output reg        s_axis_cmd_write,
    output reg        s_axis_cmd_write_multiple,
    output reg        s_axis_cmd_stop,
    output reg        s_axis_cmd_valid,
    input  wire       s_axis_cmd_ready,

    output reg [7:0]  s_axis_data_tdata,
    output reg        s_axis_data_tvalid,
    input  wire       s_axis_data_tready,
    output reg        s_axis_data_tlast,

    input wire [7:0]  m_axis_data_tdata,
    input wire        m_axis_data_tvalid,
    output reg        m_axis_data_tready,
    input wire        m_axis_data_tlast
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
		START,
        WRITE_DEV_ADDR,
        WRITE_MEM_ADDR,
        WRITE_DATA,
        STOP_BEFORE_READ,
        READ_DATA_REPEATED_START,
        SET_HIGH_READ_ACK,
        READ_DATA,
        STOP
    } state_t;

    state_t current_state = IDLE, next_state;

    // Registers for address and data
    reg [6:0] device_addr;
    reg [7:0] mem_addr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            busy <= 0;
        end else begin
            if (current_state != IDLE) begin
                busy <= 1;
            end else begin
                busy <= 0;
            end
            current_state <= next_state;
        end
    end

    always_comb begin
        // Internal registers
        device_addr = 7'b0;
        mem_addr = 8'b0;
        
        // User outputs
        data_out = 8'b0;
        
        // AXIL signals
        s_axis_cmd_address        = 7'b0;
        s_axis_cmd_start          = 1'b0;
        s_axis_cmd_write          = 1'b0;
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
                if (start) begin
                    next_state = START;
                end
            end
			START: begin
                // Start
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_address = device_addr;
                s_axis_cmd_start = 1'b1;
                s_axis_cmd_valid = 1'b1;
				if (s_axis_cmd_ready) begin
				    next_state = WRITE_DEV_ADDR;
				end
			end
            WRITE_DEV_ADDR: begin
                // Write device address with r/w set to write
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_address = device_addr;
                s_axis_cmd_start = 1'b1;
                s_axis_cmd_write_multiple = 1'b1; 
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready) begin
                    next_state = WRITE_MEM_ADDR;
                end
            end
            WRITE_MEM_ADDR: begin
                // Send the memory address
                mem_addr = mem_address;
                s_axis_data_tdata = mem_addr;
                s_axis_data_tvalid = 1'b1;
                if (s_axis_data_tready) begin
                    if (write_enable) begin
                        next_state = WRITE_DATA;
                    end else if (read_enable) begin
                        next_state = STOP_BEFORE_READ;
                    end
                end
            end
            WRITE_DATA: begin
                // Write data
                s_axis_data_tdata = data_in;
                s_axis_data_tvalid = 1'b1;
                if (s_axis_data_tready) begin
                    next_state = STOP;
                end
            end
            STOP_BEFORE_READ: begin
                // Issue stop command before read
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_address = device_addr;
                s_axis_cmd_stop = 1'b1;
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready) begin
                    next_state = READ_DATA_REPEATED_START;
                end
            end
            READ_DATA_REPEATED_START: begin
                // Issue repeated start condition for read
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_address = device_addr;
                s_axis_cmd_start = 1'b1;
                s_axis_cmd_read = 1'b1;
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                // Read data
                m_axis_data_tready = 1'b1;
                if (m_axis_data_tvalid) begin
                    data_out = m_axis_data_tdata;
                    next_state = STOP;
                end
            end
            STOP: begin
                // Issue stop
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axis_cmd_address = device_addr;
                s_axis_cmd_stop = 1'b1;
                s_axis_cmd_valid = 1'b1;
                if (s_axis_cmd_ready) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule

