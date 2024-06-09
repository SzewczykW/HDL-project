`timescale 1ns / 1ps

/*
 * AXI4Lite Master module for FM24CL16B FRAM
 */
module axil_master #(
    parameter FM24CLXX_TYPE = 2048,  // Memory size in bytes
    parameter FM24CLXX_ADDR = 3'b000 // I2C address pins
) (
    input wire clk,
    input wire rst,
    input wire start,
    // Needs to be 16-bit reg if FM24CLXX_TYPE > 2048
    input wire [7:0] mem_address,   // 8-bit word address register
    input wire [31:0] data_in,      // Data to write
    output reg [31:0] data_out,     // Data read
    input wire write_enable,        // Write operation enable
    input wire read_enable,         // Read operation enable
    output reg busy,                // Driver busy signal

    // AXI4Lite Interface signals to connect to I2C master
    output reg [3:0] s_axil_awaddr,
    output reg s_axil_awvalid,
    input wire s_axil_awready,
    output reg [31:0] s_axil_wdata,
    output reg [3:0] s_axil_wstrb,  // Write strobe signal
    output reg s_axil_wvalid,
    input wire s_axil_wready,
    input wire [1:0] s_axil_bresp,
    input wire s_axil_bvalid,
    output reg s_axil_bready,
    output reg [3:0] s_axil_araddr,
    output reg s_axil_arvalid,
    input wire s_axil_arready,
    input wire [31:0] s_axil_rdata,
    input wire [1:0] s_axil_rresp,
    input wire s_axil_rvalid,
    output reg s_axil_rready
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        SET_PRESCALE,
		START,
        WRITE_DEV_ADDR,
        WRITE_MEM_ADDR,
        WRITE_DATA,
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
        data_out = 32'b0;
        
        // AXIL signals
        s_axil_awaddr = 4'b0;
        s_axil_awvalid = 0;
        s_axil_wdata = 32'b0;
        s_axil_wstrb = 4'b0000; // Default write strobe for 32-bit data
        s_axil_wvalid = 0;
        s_axil_bready = 0;
        s_axil_araddr = 4'b0;
        s_axil_arvalid = 0;
        s_axil_rready = 0;
        
        // Next state of FSM
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SET_PRESCALE;
                end
            end
            SET_PRESCALE: begin
                // Set the prescale value to achieve ~12.5 kHz I2C clock
                s_axil_awaddr = 4'hC; // Address for prescale register
                s_axil_wdata = 32'd2000; // Prescale value
                s_axil_wstrb = 4'b0011;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = START;
                end
            end
			START: begin
                device_addr = {4'b1010, FM24CLXX_ADDR};
				s_axil_awaddr = 4'h4; // Address for command register
	  			s_axil_wdata = {23'b0, 1'b1, 1'b0, device_addr}; // cmd_start
				s_axil_wstrb = 4'b0011;
				s_axil_awvalid = 1'b1;
				s_axil_wvalid = 1'b1;
				if (s_axil_awaddr && s_axil_wready) begin
				    next_state = WRITE_DEV_ADDR;
				end
			end
            WRITE_DEV_ADDR: begin
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axil_awaddr = 4'h4; // Address for command register
                s_axil_wdata = {21'b0, 1'b1, 3'b0, device_addr}; // cmd_write
                s_axil_wstrb = 4'b0011;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = WRITE_MEM_ADDR;
                end
            end
            WRITE_MEM_ADDR: begin
                // Send the memory address
                mem_addr = mem_address;
                s_axil_awaddr = 4'h8; // Address for data register
                s_axil_wdata = {24'b0, mem_addr};
                s_axil_wstrb = 4'b0001;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    if (write_enable) begin
                        next_state = WRITE_DATA;
                    end else if (read_enable) begin
                        next_state = READ_DATA_REPEATED_START;
                    end
                end
            end
            WRITE_DATA: begin
                // Write data
                s_axil_awaddr = 4'h8; // Address for data register
                s_axil_wdata = data_in;
                s_axil_wstrb = 4'b1111;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = STOP;
                end
            end
            READ_DATA_REPEATED_START: begin
                // Issue repeated start condition for read
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axil_awaddr = 4'h4; // Address for command register
                s_axil_wdata = {22'b0, 2'b1, 1'b0, device_addr}; // cmd_read
                s_axil_wstrb = 4'b0011;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = READ_DATA;
                end
            end
            SET_HIGH_READ_ACK: begin
                // Issue high ack as fm24clxx returns high pulse as result from read
                s_axil_awaddr = 4'h0; // Address for status register
                s_axil_wdata = {28'b0, 1'b1, 3'b0}; // missed_ack
                s_axil_wstrb = 4'b0011;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                s_axil_araddr = 4'h8; // Address for data register
                s_axil_arvalid = 1'b1;
                s_axil_rready = 1'b1;
                if (s_axil_arready && s_axil_rvalid) begin
                    data_out = s_axil_rdata;
                    next_state = STOP;
                end
            end
            STOP: begin
                device_addr = {4'b1010, FM24CLXX_ADDR};
                s_axil_awaddr = 4'h4; // Address for command register
                s_axil_wdata = {19'b0, 1'b1, 5'b0, device_addr}; // cmd_stop
                s_axil_wstrb = 4'b0011;
                s_axil_awvalid = 1'b1;
                s_axil_wvalid = 1'b1;
                if (s_axil_awready && s_axil_wready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule

