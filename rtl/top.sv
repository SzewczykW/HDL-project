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

    reg start;
    // Needs to be 16-bit reg if FM24CLXX_TYPE > 2048
    reg  [7:0]  mem_address;    // 8-bit reg for word address
    reg  [7:0]  data_in;        // Data to write (32 bits)
    reg [7:0]  data_out;       // Data read (32 bits)
    reg         write_enable;   // Write operation enable
    reg         read_enable;    // Read operation enable
    reg         busy;

    // AXIS signals
    reg [6:0]   s_axis_cmd_address;
    reg         s_axis_cmd_start;
    reg         s_axis_cmd_read;
    reg         s_axis_cmd_write;
    reg         s_axis_cmd_write_multiple;
    reg         s_axis_cmd_stop;
    reg         s_axis_cmd_valid;
    wire        s_axis_cmd_ready;

    reg [7:0]  s_axis_data_tdata;
    reg        s_axis_data_tvalid;
    wire        s_axis_data_tready;
    reg        s_axis_data_tlast;

    wire [7:0]  m_axis_data_tdata;
    wire        m_axis_data_tvalid;
    reg        m_axis_data_tready;
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

    localparam FM24CLXX_TYPE = 2048;
    localparam FM24CLXX_ADDR = 3'b000;

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
            if (current_state == IDLE) begin
                busy <= 0;
            end else begin
                busy <= 1;
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
                s_axis_data_tlast = 1'b1;
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
        IDLE_TEST,
        START_TEST,
        WRITE,
        READ,
        CHECK_READ,
        DONE
    } test_states;
    
    test_states test_state = IDLE_TEST;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            test_state <= IDLE_TEST;
            leds <= 8'b0000_0000;
            start <= 0;
            write_enable <= 0;
            read_enable <= 0;
            mem_address <= 8'h00;
            data_in <= 32'h00000000;
         end else begin
            case (test_state)
                IDLE_TEST: begin
                   mem_address <= 8'h04;
                   data_in <= 32'h000000A5;
                   test_state <= START_TEST;
                end
                START_TEST: begin
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

