`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:13:11
// Design Name: 
// Module Name: bias_memory
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



module bias_memory(
    input wire clk,
    
    // Port A: UART Write
    input wire [7:0] addr_a,
    input wire [7:0] data_a,
    input wire wr_en_a,
    input wire [1:0] layer_sel_a,
    
    // Port B: Read
    input wire [2:0] addr_b,
    output reg [7:0] data_b,
    input wire wr_en_b,
    input wire [1:0] layer_sel_b
);

    // Memory organization:
    // Layer 1: 8 biases (0-7)
    // Layer 2: 4 biases (8-11)
    // Layer 3: 2 biases (12-13)
    
    reg [7:0] memory [0:13];
    reg [3:0] mem_addr_a, mem_addr_b;
    
    always @(*) begin
        // Calculate actual memory address
        case (layer_sel_a)
            2'b00: mem_addr_a = {1'b0, addr_a[2:0]}; // Layer 1: 0-7
            2'b01: mem_addr_a = addr_a[1:0] + 4'd8; // Layer 2: 8-11
            2'b10: mem_addr_a = addr_a[0] + 4'd12; // Layer 3: 12-13
            default: mem_addr_a = 0;
        endcase
        
        case (layer_sel_b)
            2'b00: mem_addr_b = {1'b0, addr_b}; // Layer 1
            2'b01: mem_addr_b = addr_b + 4'd8; // Layer 2
            2'b10: mem_addr_b = addr_b + 4'd12; // Layer 3
            default: mem_addr_b = 0;
        endcase
    end
    
    always @(posedge clk) begin
        // Port A: Write
        if (wr_en_a) begin
            memory[mem_addr_a] <= data_a;
        end
        
        // Port B: Read
        data_b <= memory[mem_addr_b];
    end
    
    // Initial biases for simulation
    initial begin
        memory[0] = 8'h00; memory[1] = 8'h01; memory[2] = 8'h02; memory[3] = 8'h03;
        memory[4] = 8'h04; memory[5] = 8'h05; memory[6] = 8'h06; memory[7] = 8'h07;
        memory[8] = 8'h08; memory[9] = 8'h09; memory[10] = 8'h0A; memory[11] = 8'h0B;
        memory[12] = 8'h0C; memory[13] = 8'h0D;
    end
    
endmodule
