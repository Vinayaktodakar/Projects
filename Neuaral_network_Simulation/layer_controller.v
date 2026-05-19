//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:04:33
// Design Name: 
// Module Name: layer_controller
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

module layer_controller(
    input wire clk,
    input wire rst_n,
    
    // Control Interface
    input wire start,
    output reg done,
    output reg [1:0] current_layer,
    
    // Data Interface
    input wire [7:0] input_data,
    input wire input_valid,
    
    // MAC Interface
    output reg mac_start,
    input wire mac_done,
    
    // Activation Interface
    output reg act_enable,
    input wire act_done,
    
    // Output Interface
    input wire [7:0] output_data,
    output reg output_valid,
    output reg [2:0] output_idx,
    
    // Data Path Control
    output reg [7:0] mac_input,
    output reg [2:0] mac_layer_sel,
    output reg [3:0] mac_neuron_sel,
    output reg [2:0] read_counter,
    
    // Configuration
    input wire [7:0] config_data
);

    // Layer definitions
    parameter L1_IN = 4;
    parameter L1_OUT = 8;
    parameter L2_IN = 8;
    parameter L2_OUT = 4;
    parameter L3_IN = 4;
    parameter L3_OUT = 2;
    
    reg [2:0] state;
    reg [3:0] input_counter;
    reg [3:0] neuron_counter;
    
    // Layer buffer (for intermediate results)
    (* ram_style = "distributed" *) reg [7:0] layer_buffer [0:7];
    reg [7:0] buffer_valid;
    
    // Local parameters for states
    localparam [2:0]
        IDLE          = 3'b000,
        LAYER1_START  = 3'b001,
        LAYER1_COMPUTE = 3'b010,
        LAYER2_START  = 3'b011,
        LAYER2_COMPUTE = 3'b100,
        LAYER3_START  = 3'b101,
        LAYER3_COMPUTE = 3'b110,
        DONE          = 3'b111;
    
    // Initialize buffer (synthesizable) - use reset
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 8; k = k + 1) begin
                layer_buffer[k] <= 8'h00;
            end
            buffer_valid <= 8'h00;
        end else if (output_valid) begin
            // Store activation outputs in buffer
            layer_buffer[output_idx] <= output_data;
            buffer_valid[output_idx] <= 1'b1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            current_layer <= 2'b00;
            mac_start <= 0;
            act_enable <= 0;
            output_valid <= 0;
            output_idx <= 0;
            input_counter <= 0;
            neuron_counter <= 0;
            mac_input <= 0;
            mac_layer_sel <= 0;
            mac_neuron_sel <= 0;
            read_counter <= 0;
        end else begin
            // Default outputs
            mac_start <= 0;
            act_enable <= 0;
            output_valid <= 0;
            done <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LAYER1_START;
                        current_layer <= 2'b00;
                        neuron_counter <= 0;
                        input_counter <= 0;
                        read_counter <= 0;
                        buffer_valid <= 8'h00; // Clear buffer
                    end
                end
                
                LAYER1_START: begin
                    // Layer 1: Use input buffer
                    if (input_valid) begin
                        mac_input <= input_data;
                        mac_layer_sel <= 3'b000;
                        mac_neuron_sel <= neuron_counter;
                        mac_start <= 1;
                        state <= LAYER1_COMPUTE;
                        input_counter <= input_counter + 1;
                    end
                end
                
                LAYER1_COMPUTE: begin
                    if (mac_done) begin
                        if (act_done) begin
                            // Store output
                            output_valid <= 1;
                            output_idx <= neuron_counter;
                            
                            neuron_counter <= neuron_counter + 1;
                            input_counter <= 0;
                            
                            if (neuron_counter == (L1_OUT-1)) begin
                                // Layer 1 complete
                                state <= LAYER2_START;
                                current_layer <= 2'b01;
                                neuron_counter <= 0;
                                read_counter <= 0;
                            end else begin
                                state <= LAYER1_START;
                            end
                        end else begin
                            act_enable <= 1;
                        end
                    end
                end
                
                LAYER2_START: begin
                    // Layer 2: Use layer 1 outputs from buffer
                    if (buffer_valid[read_counter]) begin
                        mac_input <= layer_buffer[read_counter];
                        mac_layer_sel <= 3'b001;
                        mac_neuron_sel <= neuron_counter;
                        mac_start <= 1;
                        state <= LAYER2_COMPUTE;
                        read_counter <= read_counter + 1;
                    end
                end
                
                LAYER2_COMPUTE: begin
                    if (mac_done) begin
                        if (act_done) begin
                            if (read_counter == L2_IN) begin
                                // Finished all inputs for this neuron
                                read_counter <= 0;
                                neuron_counter <= neuron_counter + 1;
                                
                                if (neuron_counter == (L2_OUT-1)) begin
                                    // Layer 2 complete
                                    state <= LAYER3_START;
                                    current_layer <= 2'b10;
                                    neuron_counter <= 0;
                                    buffer_valid <= 8'h00; // Clear for new data
                                end else begin
                                    state <= LAYER2_START;
                                end
                            end else begin
                                state <= LAYER2_START;
                            end
                        end else begin
                            act_enable <= 1;
                        end
                    end
                end
                
                LAYER3_START: begin
                    // Layer 3: Use layer 2 outputs from buffer
                    if (buffer_valid[read_counter]) begin
                        mac_input <= layer_buffer[read_counter];
                        mac_layer_sel <= 3'b010;
                        mac_neuron_sel <= neuron_counter;
                        mac_start <= 1;
                        state <= LAYER3_COMPUTE;
                        read_counter <= read_counter + 1;
                    end
                end
                
                LAYER3_COMPUTE: begin
                    if (mac_done) begin
                        if (act_done) begin
                            // Output final result
                            output_valid <= 1;
                            output_idx <= neuron_counter;
                            
                            if (read_counter == L3_IN) begin
                                read_counter <= 0;
                                neuron_counter <= neuron_counter + 1;
                                
                                if (neuron_counter == (L3_OUT-1)) begin
                                    // All done
                                    state <= DONE;
                                end else begin
                                    state <= LAYER3_START;
                                end
                            end else begin
                                state <= LAYER3_START;
                            end
                        end else begin
                            act_enable <= 1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule