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
    input wire [10:0] mem_address,  // 11-bit address for 2KB memory
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
    typedef enum logic [4:0] {
        IDLE,
        START,
        SEND_DEVICE_ADDR_HIGH,
        SEND_DEVICE_ADDR_LOW,
        WAIT_AWREADY,
        SEND_MEM_ADDR,
        WAIT_WREADY_MEM,
        WRITE_DATA,
		WAIT_WREADY_DATA,
		WAIT_BVALID_DATA,
        READ_DATA_REPEATED_START,
        SEND_DEVICE_ADDR_HIGH_READ,
        SEND_DEVICE_ADDR_LOW_READ,
        READ_DATA,
        WAIT_RVALID,
        STOP
    } state_t;

    state_t current_state = IDLE, next_state;

    // Registers for address and data
    reg [7:0] device_addr;
    reg [15:0] mem_addr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        // Internal registers
        device_addr = 8'b0;
        mem_addr = 16'b0;
        
        // User outputs
        data_out = 32'b0;
        busy = 1;
        
        // AXIL signals
        s_axil_awaddr = 4'b0;
        s_axil_awvalid = 0;
        s_axil_wdata = 32'b0;
        s_axil_wstrb = 4'b1111; // Default write strobe for 32-bit data
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
                    next_state = START;
                    device_addr = {4'b1010, FM24CLXX_ADDR, 1'b0};
                    mem_addr = mem_address;
                end
            end
            START: begin
                busy = 1;
                if (write_enable || read_enable) begin
                    next_state = SEND_DEVICE_ADDR_HIGH;
                end else begin
                    next_state = IDLE;
                end
            end
            SEND_DEVICE_ADDR_HIGH: begin
                s_axil_awaddr = device_addr[7:4];
                s_axil_awvalid = 1;
                next_state = SEND_DEVICE_ADDR_LOW;
            end
            SEND_DEVICE_ADDR_LOW: begin
                if (s_axil_awready) begin
                    s_axil_awaddr = device_addr[3:0];
                    s_axil_awvalid = 1;
                    next_state = WAIT_AWREADY;
                end
            end
            WAIT_AWREADY: begin
                if (s_axil_awready) begin
                    next_state = SEND_MEM_ADDR;
                end
            end
            SEND_MEM_ADDR: begin
                s_axil_wdata = {16'b0, mem_addr};
                s_axil_wvalid = 1;
                next_state = WAIT_WREADY_MEM;
            end
            WAIT_WREADY_MEM: begin
                if (s_axil_wready) begin
                    if (write_enable) begin
                        next_state = WRITE_DATA;
                    end else if (read_enable) begin
                        next_state = READ_DATA_REPEATED_START;
                    end
                end 
            end   
            WRITE_DATA: begin
                s_axil_wdata = data_in;
                s_axil_wvalid = 1;
				next_state = WAIT_WREADY_DATA;
            end
			WAIT_WREADY_DATA: begin
                if (s_axil_wready) begin
                    s_axil_bready = 1;
                    next_state = WAIT_BVALID_DATA;
                end
			end
			WAIT_BVALID_DATA: begin
			    if (s_axil_bvalid) begin
                    next_state = STOP;
                end
            end
            READ_DATA_REPEATED_START: begin
                device_addr = {4'b1010, FM24CLXX_ADDR, 1'b1};  // Device address with read bit
                next_state = SEND_DEVICE_ADDR_HIGH_READ;
            end
            SEND_DEVICE_ADDR_HIGH_READ: begin
                s_axil_araddr = device_addr[7:4];
				s_axil_arvalid = 1;
				next_state = SEND_DEVICE_ADDR_LOW_READ;
            end
			SEND_DEVICE_ADDR_LOW_READ: begin
				if (s_axil_arready) begin
					s_axil_araddr = device_addr[3:0];
					s_axil_arvalid = 1;
					next_state = READ_DATA;
                end
			end
            READ_DATA: begin
                s_axil_rready = 1;
                next_state = WAIT_RVALID;
            end
            WAIT_RVALID: begin
                if (s_axil_rvalid) begin
					data_out = s_axil_rdata;
                    next_state = STOP;
                end
            end
            STOP: begin
                busy = 0;
                next_state = IDLE;
            end
        endcase
    end

endmodule
