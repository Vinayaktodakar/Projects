`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:10:40
// Design Name: 
// Module Name: activation_unit
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


module activation_unit(
    input wire clk,
    input wire rst_n,
    
    // Data Input
    input wire [31:0] data_in,
    
    // Configuration
    input wire [1:0] act_type,
    
    // Control
    input wire enable,
    output reg done,
    
    // Data Output (8-bit quantized)
    output reg [7:0] data_out
);

    // Activation types
    localparam [1:0]
        ACT_RELU = 2'b00,
        ACT_SIGMOID = 2'b01,
        ACT_TANH = 2'b10,
        ACT_LINEAR = 2'b11;
    
    // LUT declarations (ROM)
    (* rom_style = "distributed" *) reg [7:0] sigmoid_lut [0:7];
    (* rom_style = "distributed" *) reg [7:0] tanh_lut [0:7];
    
    // Initialize LUTs with constant values (synthesizable)
    wire [7:0] sigmoid_lut_wire [0:7];
    wire [7:0] tanh_lut_wire [0:7];
    
    assign sigmoid_lut_wire[0] = 8'h00; // -inf to -3
    assign sigmoid_lut_wire[1] = 8'h10; // -3 to -2
    assign sigmoid_lut_wire[2] = 8'h30; // -2 to -1
    assign sigmoid_lut_wire[3] = 8'h50; // -1 to 0
    assign sigmoid_lut_wire[4] = 8'h80; // 0 to 1
    assign sigmoid_lut_wire[5] = 8'hB0; // 1 to 2
    assign sigmoid_lut_wire[6] = 8'hD0; // 2 to 3
    assign sigmoid_lut_wire[7] = 8'hFF; // 3 to inf
    
    assign tanh_lut_wire[0] = 8'h80; // -1.0
    assign tanh_lut_wire[1] = 8'h90; // -0.75
    assign tanh_lut_wire[2] = 8'hB0; // -0.25
    assign tanh_lut_wire[3] = 8'hC0; // 0.0
    assign tanh_lut_wire[4] = 8'hD0; // 0.25
    assign tanh_lut_wire[5] = 8'hE0; // 0.75
    assign tanh_lut_wire[6] = 8'hF0; // 1.0
    assign tanh_lut_wire[7] = 8'hF0; // 1.0
    
    reg [2:0] state;
    reg [31:0] input_reg;
    reg [2:0] index;
    
    localparam [2:0]
        IDLE = 3'b000,
        PROCESS = 3'b001,
        LUT_LOOKUP = 3'b010,
        OUTPUT = 3'b011;
    
    // Load LUTs from wires (synthesizable)
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 8; i = i + 1) begin
            sigmoid_lut[i] <= sigmoid_lut_wire[i];
            tanh_lut[i] <= tanh_lut_wire[i];
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            data_out <= 0;
            input_reg <= 0;
            index <= 0;
        end else begin
            done <= 0;
            
            case (state)
                IDLE: begin
                    if (enable) begin
                        input_reg <= data_in;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    case (act_type)
                        ACT_RELU: begin
                            // ReLU: max(0, x)
                            if (input_reg[31]) begin // Negative
                                data_out <= 8'h00;
                            end else begin
                                // Saturate to 8-bit
                                if (input_reg > 255) begin
                                    data_out <= 8'hFF;
                                end else begin
                                    data_out <= input_reg[7:0];
                                end
                            end
                            state <= OUTPUT;
                        end
                        
                        ACT_SIGMOID: begin
                            // Simplified sigmoid using LUT
                            // Map input to 3-bit index
                            index <= (input_reg[31] ? 3'b000 : 
                                     (input_reg[30] ? 3'b001 :
                                     (input_reg[29] ? 3'b010 :
                                     (input_reg[28] ? 3'b011 :
                                     (input_reg[27] ? 3'b100 :
                                     (input_reg[26] ? 3'b101 :
                                     (input_reg[25] ? 3'b110 : 3'b111)))))));
                            state <= LUT_LOOKUP;
                        end
                        
                        ACT_TANH: begin
                            // Simplified tanh using LUT
                            index <= (input_reg[31] ? 3'b000 : 
                                     (input_reg[30] ? 3'b001 :
                                     (input_reg[29] ? 3'b010 :
                                     (input_reg[28] ? 3'b011 :
                                     (input_reg[27] ? 3'b100 :
                                     (input_reg[26] ? 3'b101 :
                                     (input_reg[25] ? 3'b110 : 3'b111)))))));
                            state <= LUT_LOOKUP;
                        end
                        
                        ACT_LINEAR: begin
                            // Linear: just quantize
                            if (input_reg > 255) begin
                                data_out <= 8'hFF;
                            end else if (input_reg < -256) begin
                                data_out <= 8'h00;
                            end else begin
                                // Convert to unsigned 8-bit
                                data_out <= input_reg[7:0] + 8'h80;
                            end
                            state <= OUTPUT;
                        end
                    endcase
                end
                
                LUT_LOOKUP: begin
                    // Use LUT based on activation type
                    if (act_type == ACT_SIGMOID) begin
                        data_out <= sigmoid_lut[index];
                    end else begin // ACT_TANH
                        data_out <= tanh_lut[index];
                    end
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule