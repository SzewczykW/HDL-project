`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/08/2024 07:24:55 PM
// Design Name: 
// Module Name: axi_master
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


module axi_master #(parameter nbadr = 5)(
    input clk,
    input rst,
    output logic [3:0] awadr, output logic awvld, input awrdy,//AW
    output [31:0] wdat, output logic wvld, input wrdy,//W
    input bvld, output logic brdy,//B
    output logic [3:0] aradr, output logic arvld, input arrdy,//AR
    input [7:0] rdat, input rvld, output logic rrdy, //R
    output logic [7:0] data_in, input [7:0] data_out, output logic wr, rd, output logic [nbadr-1:0] mem_adr
    );
    
logic rec_trn = 1'b1;
logic cmdm;
logic [5:0] maxadr;

typedef enum {ReadStatus, WaitStatus, Read, Write, WaitRead, Command, WaitWrite, WaitResp} states;
states st, nst;

wire rfifo_valid = ((st == WaitStatus) && rvld) ? rdat[0] : 1'b0;
wire tfifo_full = ((st == WaitStatus) && rvld) ? rdat[3] : 1'b0;

always @(posedge clk, posedge rst)
    if(rst)
        st <= ReadStatus;
    else
        st <= nst;
        
always @* begin
    nst = ReadStatus;
    case(st)
        ReadStatus: nst = WaitStatus;
        WaitStatus: if(rec_trn)
            nst = rfifo_valid ? (rvld ? Read : WaitStatus) : ReadStatus ;
        else
            nst = tfifo_full ? ReadStatus : (rvld ? Write : WaitStatus) ;
        Read: nst = WaitRead;
        WaitRead: nst = rvld ? (rdat[7] ? Command : ReadStatus) : WaitRead;
        Command: nst = ReadStatus;
        Write: nst = WaitWrite;
        WaitWrite: nst = awrdy ? WaitResp : WaitWrite;
        WaitResp: nst = bvld ? ReadStatus : WaitResp;
    endcase
end
 // AR   
always @(posedge clk, posedge rst)
    if(rst)
        aradr <= 4'b0;
    else if(st == ReadStatus)
        aradr <= 4'd8;
    else
        aradr <= 4'b0;
       
always @(posedge clk, posedge rst)
    if(rst)
        arvld <= 1'b0;
    else if(st == ReadStatus || st == Read)
        arvld <= 1'b1;
    else if(arrdy)
        arvld <= 1'b0;
 // R       
always @(posedge clk, posedge rst)
    if(rst)
        rrdy <= 1'b0;
    else if((st == WaitStatus || st == WaitRead) && rvld)
        rrdy <= 1'b1;
    else
        rrdy <= 1'b0;
// memory write
wire incar = (st == WaitRead) & rec_trn & ~cmdm & rvld & (mem_adr < maxadr);
wire incat = (st == Write) & ~rec_trn & cmdm & (mem_adr < maxadr);
wire st_resp = (st == WaitResp) && (mem_adr == maxadr);

always @(posedge clk, posedge rst)
    if(rst)
        data_in <= 8'b0;
    else if(incar)
        data_in <= rdat[7:0];
        
always @(posedge clk, posedge rst)
    if(rst)
        wr <= 1'b0;
    else
        wr <= incar;
    
always @(posedge clk, posedge rst)
    if(rst)
        rd <= 1'b0;
    else
        rd <= (st == Write);
 // address generator       
always @(posedge clk)
    if(rst)
        mem_adr <= {nbadr{1'b0}};
    else if(incar | incat)
        mem_adr <= mem_adr + 1'b1;
    else if (st_resp || st == Command)
        mem_adr <= {nbadr{1'b0}};
// command decoder DO ROZWINIECIA
always @(posedge clk)
    if(rst) begin
        rec_trn <= 1'b1;
        cmdm <= 1'b1;
        maxadr <= 6'b0;
    end
    else if(st == Command) begin
        rec_trn <= 1'b1;
        cmdm <= 1'b1;
        maxadr <= rdat[5:0];
        case(rdat[7:6])
            2'b10: cmdm <= (rdat[5:0] == 6'b0) ? 1'b1 : 1'b0; 
            2'b11: rec_trn <= 1'b0;
        endcase
    end
    else if(st_resp) begin
            rec_trn <= 1'b1;
            cmdm <= 1'b1;
        end
// AW
always @(posedge clk, posedge rst)
    if(rst)
        awadr <= 4'b0;
    else if(st == Write || st == WaitWrite)
        awadr <= 4'd4;
    else
        awadr <= 4'b0;

always @(posedge clk, posedge rst)
    if(rst)
        awvld <= 1'b0;
    else if(st == Write)
        awvld <= 1'b1;
    else if(awrdy)
        awvld <= 1'b0;

// W
always @(posedge clk, posedge rst)
    if(rst)
        wvld <= 1'b0;
    else if(st == Write)
        wvld <= 1'b1;
    else if(wrdy)
        wvld <= 1'b0;
assign wdat = (st == WaitWrite) ? {24'b0, data_out} : 32'b0;

// B
always @(posedge clk, posedge rst)
    if(rst)
        brdy <= 1'b0;
    else if(st == Write)
        brdy <= 1'b1;
    else if(bvld)
        brdy <= 1'b0;

endmodule