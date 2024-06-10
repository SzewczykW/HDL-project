`timescale 1ns / 1ps

module tb_axis_master();
    reg        clk;
    reg        rst;

    reg        start;
    reg [7:0]  mem_address;         // 8-bit word address register
    reg [7:0]  data_in;             // Data to write
    reg [7:0]  data_out;            // Data read
    reg        write_enable;        // Write operation enable
    reg        read_enable;         // Read operation enable
    wire       busy;                // Driver busy signal

    wire [6:0] s_axis_cmd_address;
    wire       s_axis_cmd_start;
    wire       s_axis_cmd_read;
    wire       s_axis_cmd_write;
    wire       s_axis_cmd_write_multiple;
    wire       s_axis_cmd_stop;
    wire       s_axis_cmd_valid;
    reg        s_axis_cmd_ready;

    wire [7:0] s_axis_data_tdata;
    wire       s_axis_data_tvalid;
    reg        s_axis_data_tready;
    wire       s_axis_data_tlast;

    reg [7:0]  m_axis_data_tdata;
    reg        m_axis_data_tvalid;
    wire       m_axis_data_tready;
	wire       m_axis_data_tlast;

    parameter CLK = 5;

    initial begin
        clk = 0;
        forever #(CLK) clk = ~clk;
    end

    initial begin
        rst = 1;
        start = 0;
        s_axis_cmd_ready = 0;
        s_axis_data_tready = 0;
        m_axis_data_tdata = 8'b0;
        m_axis_data_tvalid = 0;
        
        #(10*CLK);
        rst = 0;
        
        #(20*CLK);
        start = 1;
        
        #(2*CLK);
        
        // Example assertion usage
        assert (!busy) else $fatal("ERROR: Driver is busy at start");
        
        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;

        write_enable = 1;
        if (s_axis_data_tdata && s_axis_data_tvalid) begin
            s_axis_data_tready = 1;
            #CLK;
        end
        s_axis_data_tready = 0;
        
        data_in = 8'hAA;
        mem_address = 8'h04;

        if (s_axis_data_tdata && s_axis_data_tvalid) begin
            s_axis_data_tready = 1;
            #CLK;
        end
        s_axis_data_tready = 0;
        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
  
        write_enable = 0;
        start = 0;
        #(2*CLK);

        start = 1;
        #(2*CLK);

        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
        
        read_enable = 1;
        if (s_axis_data_tdata && s_axis_data_tvalid) begin
            s_axis_data_tready = 1;
            #CLK;
        end
        s_axis_data_tready = 0;

        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;

        if (m_axis_data_tready) begin
            m_axis_data_tvalid = 1;
            #CLK;
        end
        m_axis_data_tvalid = 0;
        
        m_axis_data_tdata = data_in;
        #CLK;
       
        
        assert (data_out == data_in) else $fatal("ERROR: Data mismatch");

        if (s_axis_cmd_start && s_axis_cmd_valid) begin
            s_axis_cmd_ready = 1;
            #CLK;
        end
        s_axis_cmd_ready = 0;
        
        start = 0;
        #(2*CLK);

        read_enable = 0;

        #(10*CLK);
        $finish;
   end
   
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
   
endmodule
