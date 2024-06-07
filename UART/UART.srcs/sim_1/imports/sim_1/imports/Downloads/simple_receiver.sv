`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AGH
// Engineer: AS
// Create Date: 04/15/2021 11:37:27 AM
// Design Name: 
// Module Name: simple_receiver (non synthsisable)
//////////////////////////////////////////////////////////////////////////////////
//fclk - SedBoard system frequency
//baudrate - 
//nb - size of data 
//deep - number of data to receive by simple_receiver
//
module simple_receiver #(parameter fclk = 100_000_000, baudrate = 230400, nb = 8, deep = 20) 
    (input clk, rst, str, rx, output logic fin);
localparam ratio = calc_ratio(fclk, baudrate);
localparam bcntl = $clog2(nb);
logic strr, en16x, div;
logic [1:0] fedr;
logic [3:0] cnt16; 
logic [bcntl:0] cnt8; 
logic [nb-1:0] receiver_reg;
integer cnt, a;
reg [nb-1:0] rec_mem [1:deep]; //memory with received data

//detect first falling edge
always @(posedge clk, posedge rst)
    if(rst)
        fedr <= 2'b0;
    else if(~str)
        fedr <= {fedr[0], rx};
always @(posedge clk, posedge rst)
    if(rst)
        strr <= 1'b0;
    else if(fedr[1] & ~fedr[0])
        strr = 1'b1;       

//clock divider bt ratio
always @(posedge clk, posedge rst)
    if(rst) begin
        cnt <= 0;
        en16x <= 1'b0;
    end else if(strr)
        if(cnt == 0) begin
            cnt <= ratio - 1;
            en16x <= 1'b1;
        end else begin
           cnt <= cnt - 1;
            en16x <= 1'b0; 
        end
        
always @(posedge clk, posedge rst)
    if(rst) begin
        cnt16 <= 4'h0;
        div <= 1'b0;
    end else if(strr & en16x)
        if (cnt16 == 4'hf) begin
        cnt16 <= 4'h0;
        div <= 1'b1;
    end else begin
        cnt16 <= cnt16 + 1'b1;
        div <= 1'b0;
    end

always @(posedge div, posedge rst)
    if(rst)
        receiver_reg <= {nb{1'b0}};
    else
        receiver_reg <= {rx, receiver_reg[nb-1:1]};
        
always @(posedge div, posedge rst, posedge str)
    if(rst | str)
        cnt8 <= {(bcntl+1){1'b0}};
    else if(cnt8 == 9)
        cnt8 <= {(bcntl+1){1'b0}};
    else if(strr)
        cnt8 <= cnt8 + 1;
        
always @(posedge clk, posedge rst)
    if(rst)
        fin <= 1'b0;
    else if(cnt8 == 4'h9 & strr & (a > 0))
        fin <= 1'b1;
    else
        fin <= 1'b0;
      
always @(posedge clk, posedge rst)
    if(rst)
        a = deep;
    else if(div & en16x & fin)
        rec_mem[a--] = receiver_reg;
        else if(str)
            a = deep;
        
function integer calc_ratio(input integer fclk, baudrate);
integer brate_mult16_div2, reminder, ratio;
begin
    brate_mult16_div2 = 8*baudrate;
    reminder = fclk % (16 * baudrate);
    ratio = fclk / (16 * baudrate);
    if (brate_mult16_div2 < reminder)
        calc_ratio = ratio+1;
    else
        calc_ratio = ratio;
end
endfunction

endmodule