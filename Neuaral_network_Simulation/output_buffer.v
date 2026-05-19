`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:08:33
// Design Name: 
// Module Name: output_buffer
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


module output_buffer(
    input wire clk,
    input wire rst_n,
    
    // Data Input
    input wire [7:0] data_in,
    input wire wr_en,
    input wire [2:0] idx,
    
    // Data Output (for reading)
    output reg [7:0] data_out,
    
    // UART TX Interface
    output reg [7:0] tx_data,
    output reg tx_start,
    input wire tx_ready
);

    parameter BUFFER_SIZE = 8;
    
    reg [7:0] buffer [0:BUFFER_SIZE-1];
    reg [2:0] read_idx;
    reg [1:0] state;
    reg tx_busy;
    
    localparam [1:0]
        IDLE = 2'b00,
        STORE = 2'b01,
        TRANSMIT = 2'b10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_idx <= 0;
            tx_start <= 0;
            tx_busy <= 0;
            data_out <= 0;
            
            // Initialize buffer
            for (integer i = 0; i < BUFFER_SIZE; i = i + 1) begin
                buffer[i] <= 8'h00;
            end
        end else begin
            tx_start <= 0;
            
            case (state)
                IDLE: begin
                    if (wr_en) begin
                        // Store data
                        buffer[idx] <= data_in;
                        state <= STORE;
                    end else if (tx_ready && !tx_busy) begin
                        // Start transmission
                        state <= TRANSMIT;
                        read_idx <= 0;
                    end
                end
                
                STORE: begin
                    // Data stored, check if we should transmit
                    if (idx == 3'd7) begin // Last output
                        state <= TRANSMIT;
                        read_idx <= 0;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                TRANSMIT: begin
                    if (tx_ready && !tx_busy) begin
                        tx_data <= buffer[read_idx];
                        tx_start <= 1;
                        tx_busy <= 1;
                        
                        if (read_idx == BUFFER_SIZE-1) begin
                            state <= IDLE;
                            tx_busy <= 0;
                        end else begin
                            read_idx <= read_idx + 1;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
            
            // Update data output
            data_out <= buffer[read_idx];
        end
    end
    
endmodule
