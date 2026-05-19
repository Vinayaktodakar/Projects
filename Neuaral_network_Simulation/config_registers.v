`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:07:52
// Design Name: 
// Module Name: config_registers
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
 

module config_registers(
    input wire clk,
    input wire rst_n,
    
    // Configuration Interface
    input wire [3:0] addr,
    input wire [7:0] data_in,
    input wire wr_en,
    
    // Control Outputs
    output reg [1:0] act_type,
    output reg layer_start,
    output reg layer_done,
    
    // Debug
    output reg [7:0] debug_state
);

    // Configuration registers
    reg [7:0] config_regs [0:15];
    
    // Register map:
    // 0x0: Control register
    // 0x1: Layer 1 config
    // 0x2: Layer 2 config
    // 0x3: Layer 3 config
    // 0x4-0xF: Reserved
    
    // Control register bits:
    // [1:0]: Global activation type override
    // [2]: Start inference
    // [3]: Reset
    // [7:4]: Debug mode
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize registers
            config_regs[0] <= 8'h00; // Control
            config_regs[1] <= 8'h00; // Layer 1: ReLU
            config_regs[2] <= 8'h00; // Layer 2: ReLU
            config_regs[3] <= 8'h03; // Layer 3: Linear
            
            act_type <= 2'b00;
            layer_start <= 0;
            layer_done <= 0;
            debug_state <= 0;
        end else begin
            layer_start <= 0;
            
            // Write to registers
            if (wr_en) begin
                config_regs[addr] <= data_in;
                
                // Special handling for control register
                if (addr == 4'h0) begin
                    if (data_in[2]) begin // Start bit
                        layer_start <= 1;
                    end
                    if (data_in[3]) begin // Reset bit
                        // Reset other registers
                        config_regs[1] <= 8'h00;
                        config_regs[2] <= 8'h00;
                        config_regs[3] <= 8'h03;
                    end
                end
            end
            
            // Update outputs
            act_type <= config_regs[0][1:0]; // Global activation override
            
            // Update debug state
            debug_state <= config_regs[0][7:4];
        end
    end
    
endmodule
