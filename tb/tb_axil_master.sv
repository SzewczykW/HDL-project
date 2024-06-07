module tb_axil_master;
    // TODO: Create i2c_master_axil instantce here to make full contact as it is in hardware!!!
    // Parameters
    parameter FM24CLXX_TYPE = 2048;  // Memory size in bytes
    parameter FM24CLXX_ADDR = 3'b000; // I2C address pins

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg [10:0] mem_address;
    reg [31:0] data_in;
    reg write_enable;
    reg read_enable;

    // Outputs
    wire [31:0] data_out;
    wire busy;

    // AXI4Lite Interface signals
    wire [3:0] s_axil_awaddr;
    wire s_axil_awvalid;
    reg s_axil_awready;
    wire [31:0] s_axil_wdata;
    wire [3:0] s_axil_wstrb;
    wire s_axil_wvalid;
    reg s_axil_wready;
    reg [1:0] s_axil_bresp;
    reg s_axil_bvalid;
    wire s_axil_bready;
    wire [3:0] s_axil_araddr;
    wire s_axil_arvalid;
    reg s_axil_arready;
    reg [31:0] s_axil_rdata;
    reg [1:0] s_axil_rresp;
    reg s_axil_rvalid;
    wire s_axil_rready;

    // Instantiate the Unit Under Test (UUT)
    axil_master #(
        .FM24CLXX_TYPE(FM24CLXX_TYPE),
        .FM24CLXX_ADDR(FM24CLXX_ADDR)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mem_address(mem_address),
        .data_in(data_in),
        .data_out(data_out),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .busy(busy),
        .m_axil_awaddr(s_axil_awaddr),
        .m_axil_awvalid(s_axil_awvalid),
        .m_axil_awready(s_axil_awready),
        .m_axil_wdata(s_axil_wdata),
        .m_axil_wstrb(s_axil_wstrb),
        .m_axil_wvalid(s_axil_wvalid),
        .m_axil_wready(s_axil_wready),
        .m_axil_bresp(s_axil_bresp),
        .m_axil_bvalid(s_axil_bvalid),
        .m_axil_bready(s_axil_bready),
        .m_axil_araddr(s_axil_araddr),
        .m_axil_arvalid(s_axil_arvalid),
        .m_axil_arready(s_axil_arready),
        .m_axil_rdata(s_axil_rdata),
        .m_axil_rresp(s_axil_rresp),
        .m_axil_rvalid(s_axil_rvalid),
        .m_axil_rready(s_axil_rready)
    );
    
    

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 0;
        start = 0;
        mem_address = 0;
        data_in = 0;
        write_enable = 0;
        read_enable = 0;
        s_axil_awready = 0;
        s_axil_wready = 0;
        s_axil_bresp = 2'b00;
        s_axil_bvalid = 0;
        s_axil_arready = 0;
        s_axil_rdata = 0;
        s_axil_rresp = 2'b00;
        s_axil_rvalid = 0;

        // Wait for global reset
        #100;
        
        // Test write operation
        mem_address = 11'h005;
        data_in = 32'hA5A5A5A5;
        write_enable = 1;
        start = 1;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        start = 0;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_wready = s_axil_wvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_wready = s_axil_wvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_bvalid = s_axil_bready ? 1'b1 : 1'b0;
        #10;
        s_axil_bvalid = s_axil_bready ? 1'b1 : 1'b0;
        write_enable = 0;
        #10;

        // Test read operation
        mem_address = 11'h005;
        read_enable = 1;
        start = 1;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        start = 0;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_awready = s_axil_awvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_wready = s_axil_wvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_wready = s_axil_wvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_arready = s_axil_arvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_arready = s_axil_arvalid ? 1'b1 : 1'b0;
        #10;
        s_axil_rdata = 32'hA5A5A5A5;
        s_axil_rvalid = s_axil_rready ? 1'b1 : 1'b0;
        #10;
        s_axil_rvalid = s_axil_rready ? 1'b1 : 1'b0;
        #10;
        assert (s_axil_rdata == data_out) $error("Data mismatch");
        read_enable = 0;
        #10;

        $finish;
    end

    always #5 clk = ~clk;

endmodule
