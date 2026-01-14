`timescale 1ns/1ps
module rpt_spram #(
    parameter ADDR_W = 5,
    parameter DEPTH  = 18,
    parameter DATA_W = 8
)(
    input                  clk,
    input                  we,
    input      [ADDR_W-1:0] addr,
    input  signed [DATA_W-1:0] wdata,
    output reg signed [DATA_W-1:0] rdata
);
    reg signed [DATA_W-1:0] mem [0:DEPTH-1];
    integer i;

    // Initialize for simulation
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 0;
        rdata = 0;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule