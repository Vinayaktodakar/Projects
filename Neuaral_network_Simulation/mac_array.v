`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:11:39
// Design Name: 
// Module Name: mac_array
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



`timescale 1ns / 1ps

module mac_array(
    input wire clk,
    input wire rst_n,
    
    // Data Inputs
    input wire [7:0] data_in,
    input wire [7:0] weight_in,
    
    // Control
    input wire start,
    output reg done,
    
    // Results
    output reg [31:0] result,
    
    // Configuration
    input wire [2:0] layer_sel,
    input wire [3:0] neuron_sel,
    
    // Activation Interface
    output reg [1:0] act_type,
    output reg [31:0] act_input
);

    // Internal registers
    reg [31:0] accumulator;
    reg [7:0] input_reg;
    reg [7:0] weight_reg;
    reg [3:0] counter;
    reg [2:0] state;
    
    // Layer configurations
    // Layer 1: 4 inputs, 8 outputs
    // Layer 2: 8 inputs, 4 outputs  
    // Layer 3: 4 inputs, 2 outputs
    
    localparam [2:0]
        IDLE  = 3'b000,
        LOAD  = 3'b001,
        MULT  = 3'b010,
        ACCUM = 3'b011,
        WAIT  = 3'b100,
        DONE_ST = 3'b101;
    
    // Activation types
    localparam [1:0]
        ACT_RELU = 2'b00,
        ACT_SIGMOID = 2'b01,
        ACT_TANH = 2'b10,
        ACT_LINEAR = 2'b11;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 32'b0;
            result <= 32'b0;
            done <= 1'b0;
            counter <= 4'b0;
            act_input <= 32'b0;
            act_type <= ACT_RELU;
            input_reg <= 8'b0;
            weight_reg <= 8'b0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        accumulator <= 32'b0;
                        counter <= 4'b0;
                        
                        // Set activation type based on layer
                        case (layer_sel)
                            3'b000: act_type <= ACT_RELU;    // Layer 1
                            3'b001: act_type <= ACT_RELU;    // Layer 2  
                            3'b010: act_type <= ACT_LINEAR;  // Layer 3
                            default: act_type <= ACT_RELU;
                        endcase
                    end
                end
                
                LOAD: begin
                    input_reg <= data_in;
                    weight_reg <= weight_in;
                    state <= MULT;
                end
                
                MULT: begin
                    // Fixed-point multiplication (8-bit * 8-bit = 16-bit)
                    // We'll use 8.8 fixed point format
                    state <= ACCUM;
                end
                
                ACCUM: begin
                    // Accumulate multiplication result
                    accumulator <= accumulator + (input_reg * weight_reg);
                    counter <= counter + 1;
                    
                    // Check if done based on layer
                    case (layer_sel)
                        3'b000: begin // Layer 1: 4 inputs
                            if (counter == 4) begin
                                state <= WAIT;
                            end else begin
                                state <= LOAD;
                            end
                        end
                        3'b001: begin // Layer 2: 8 inputs
                            if (counter == 8) begin
                                state <= WAIT;
                            end else begin
                                state <= LOAD;
                            end
                        end
                        3'b010: begin // Layer 3: 4 inputs
                            if (counter == 4) begin
                                state <= WAIT;
                            end else begin
                                state <= LOAD;
                            end
                        end
                        default: state <= WAIT;
                    endcase
                end
                
                WAIT: begin
                    // Add bias (would come from bias memory)
                    act_input <= accumulator; // Pass to activation unit
                    state <= DONE_ST;
                end
                
                DONE_ST: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule