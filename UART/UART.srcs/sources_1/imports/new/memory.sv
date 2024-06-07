`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2024 08:59:38 PM
// Design Name: 
// Module Name: memory
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


module memory #(parameter depth = 20, nbadr = $clog2(depth))(
    input clk,
    input wr,
    input rd,
    input [nbadr-1:0] addr,
    input [7:0] data_in,
    output logic [7:0] data_out
    );
    
logic [7:0] mem [1:depth];
initial $readmemh("init_mem.mem", mem);

always @(posedge clk)
    if(wr)
        mem[addr] <= data_in;
    else if(rd)
        data_out <= mem[addr];
        
endmodule

