`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:14:00
// Design Name: 
// Module Name: weight_memory
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


module weight_memory(
    input wire clk,
    
    // Port A: UART Write
    input wire [9:0] addr_a,
    input wire [7:0] data_a,
    input wire wr_en_a,
    input wire [1:0] layer_sel_a,
    
    // Port B: MAC Read
    input wire [3:0] addr_b,
    output reg [7:0] data_b,
    input wire wr_en_b,
    input wire [1:0] layer_sel_b
);

    // Memory organization:
    // Layer 1: 4x8 = 32 weights (0-31)
    // Layer 2: 8x4 = 32 weights (32-63)
    // Layer 3: 4x2 = 8 weights (64-71)
    
    (* ram_style = "block" *) reg [7:0] memory [0:71];
    reg [7:0] mem_addr_a, mem_addr_b;
    
    // Default weights (can be loaded via UART)
    wire [7:0] default_weights [0:71];
    
    // Assign default weights
    generate
        genvar k;
        for (k = 0; k < 72; k = k + 1) begin : DEFAULT_WEIGHTS
            assign default_weights[k] = (k < 72) ? (k[7:0] + 8'h01) : 8'h00;
        end
    endgenerate
    
    // Load default weights on reset (synthesizable)
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 72; i = i + 1) begin
            if (wr_en_a && (mem_addr_a == i)) begin
                // Override with UART data
            end else if (!wr_en_a) begin
                // Keep default (synthesizable initialization)
                memory[i] <= default_weights[i];
            end
        end
    end
    
    always @(*) begin
        // Calculate actual memory address based on layer selection
        case (layer_sel_a)
            2'b00: mem_addr_a = addr_a[7:0]; // Layer 1: 0-31
            2'b01: mem_addr_a = addr_a[7:0] + 8'd32; // Layer 2: 32-63
            2'b10: mem_addr_a = addr_a[7:0] + 8'd64; // Layer 3: 64-71
            default: mem_addr_a = 0;
        endcase
        
        case (layer_sel_b)
            2'b00: mem_addr_b = addr_b + 8'd0; // Layer 1
            2'b01: mem_addr_b = addr_b + 8'd32; // Layer 2
            2'b10: mem_addr_b = addr_b + 8'd64; // Layer 3
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
    
endmodule