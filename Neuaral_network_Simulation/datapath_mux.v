`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:31:29
// Design Name: 
// Module Name: datapath_mux
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


module datapath_mux(
    input wire clk,
    input wire rst_n,
    
    // Input from activation unit
    input wire [7:0] act_data_in,
    input wire act_valid_in,
    input wire [2:0] act_idx_in,
    
    // Input from input buffer
    input wire [7:0] input_data_in,
    input wire input_valid_in,
    
    // Configuration
    input wire [1:0] current_layer,
    input wire [2:0] read_counter,
    
    // Output to MAC
    output reg [7:0] data_out,
    output reg valid_out
);

    // Layer buffer (stores intermediate results)
    (* ram_style = "distributed" *) reg [7:0] layer_buffer [0:7];
    reg [7:0] buffer_valid; // One bit per buffer location
    
    // Buffer initialization (synthesizable)
    wire [7:0] default_buffer [0:7];
    
    assign default_buffer[0] = 8'h00;
    assign default_buffer[1] = 8'h00;
    assign default_buffer[2] = 8'h00;
    assign default_buffer[3] = 8'h00;
    assign default_buffer[4] = 8'h00;
    assign default_buffer[5] = 8'h00;
    assign default_buffer[6] = 8'h00;
    assign default_buffer[7] = 8'h00;
    
    // Initialize buffer (synthesizable)
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 8; j = j + 1) begin
                layer_buffer[j] <= default_buffer[j];
            end
            buffer_valid <= 8'h00;
            data_out <= 0;
            valid_out <= 0;
        end else begin
            valid_out <= 0;
            
            // Store activation outputs in buffer
            if (act_valid_in) begin
                layer_buffer[act_idx_in] <= act_data_in;
                buffer_valid[act_idx_in] <= 1'b1;
            end
            
            // Route data based on current layer
            case (current_layer)
                2'b00: begin // Layer 1: Use input buffer
                    if (input_valid_in) begin
                        data_out <= input_data_in;
                        valid_out <= 1;
                    end
                end
                
                2'b01: begin // Layer 2: Use layer 1 outputs
                    if (buffer_valid != 8'h00) begin
                        data_out <= layer_buffer[read_counter];
                        valid_out <= 1;
                    end
                end
                
                2'b10: begin // Layer 3: Use layer 2 outputs
                    if (buffer_valid != 8'h00) begin
                        data_out <= layer_buffer[read_counter];
                        valid_out <= 1;
                    end
                end
                
                default: begin
                    data_out <= 0;
                    valid_out <= 0;
                end
            endcase
        end
    end
    
endmodule
