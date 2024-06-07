`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/08/2024 07:12:11 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top #(parameter depth = 20) (
    input clk,
    rst,
    rx,
    output tx
);

localparam nbadr = $clog2(depth);

logic [7:0] data_in;
logic [7:0] data_out;
logic [nbadr-1:0] mem_adr;

wire [3 : 0] s_axi_awaddr;
wire [31 : 0] s_axi_wdata;
wire [3 : 0] s_axi_wstrb = 4'b1111;
//wire [1 : 0] s_axi_bresp;
wire [3 : 0] s_axi_araddr;
wire [1 : 0] s_axi_rresp;
wire [7 : 0] s_axi_rdata;
wire [23:0] unused = 24'b0;

axi_uartlite_0 slave (
  .s_axi_aclk(clk),        // input wire s_axi_aclk
  .s_axi_aresetn(~rst),  // input wire s_axi_aresetn
  .interrupt(),          // output wire interrupt
  .s_axi_awaddr(s_axi_awaddr),    // input wire [3 : 0] s_axi_awaddr
  .s_axi_awvalid(s_axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(s_axi_awready),  // output wire s_axi_awready
  
  .s_axi_wdata(s_axi_wdata),      // ins_axi_brespput wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(s_axi_wstrb),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(s_axi_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(s_axi_wready),    // output wire s_axi_wready
  
  .s_axi_bresp(),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axi_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(s_axi_bready),    // input wire s_axi_bready
  
  .s_axi_araddr(s_axi_araddr),    // input wire [3 : 0] s_axi_araddr
  .s_axi_arvalid(s_axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(s_axi_arready),  // output wire s_axi_arready
  
  .s_axi_rdata({unused, s_axi_rdata}),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(s_axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(s_axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(s_axi_rready),    // input wire s_axi_rready
  
  .rx(rx),                        // input wire rx
  .tx(tx)                        // output wire tx
);

axi_master #(.nbadr(5)) master (
    .clk(clk),
    .rst(rst),
    .awadr(s_axi_awaddr), .awvld(s_axi_awvalid), .awrdy(s_axi_awready),//AW
    .wdat(s_axi_wdata), .wvld(s_axi_wvalid), .wrdy(s_axi_wready),//W
    .bvld(s_axi_bvalid), .brdy(s_axi_bready),//B
    .aradr(s_axi_araddr), .arvld(s_axi_arvalid), .arrdy(s_axi_arready),//AR
    .rdat(s_axi_rdata), .rvld(s_axi_rvalid), .rrdy(s_axi_rready), //R
    .data_in(data_in), .wr(wr), .data_out(data_out), .rd(rd), .mem_adr(mem_adr)
);

memory #(.depth(depth)) ram (
    .clk(clk),
    .wr(wr),
    .rd(rd),
    .addr(mem_adr),
    .data_in(data_in),
    .data_out(data_out)
);
    
endmodule
