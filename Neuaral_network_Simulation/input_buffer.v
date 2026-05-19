`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:12:20
// Design Name: 
// Module Name: input_buffer
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


module input_buffer(
    input wire clk,
    input wire rst_n,
    
    // Data Input
    input wire [7:0] data_in,
    input wire wr_en,
    
    // Data Output
    output reg [7:0] data_out,
    output reg valid_out,
    
    // Control
    input wire start
);

    parameter BUFFER_SIZE = 4;
    
    reg [7:0] buffer [0:BUFFER_SIZE-1];
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;
    reg [1:0] state;
    reg [1:0] sample_counter;
    
    localparam [1:0]
        IDLE = 2'b00,
        LOADING = 2'b01,
        READY = 2'b10,
        SENDING = 2'b11;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            wr_ptr <= 0;
            rd_ptr <= 0;
            valid_out <= 0;
            data_out <= 0;
            sample_counter <= 0;
            
            // Initialize buffer
            buffer[0] <= 8'h01;
            buffer[1] <= 8'h02;
            buffer[2] <= 8'h03;
            buffer[3] <= 8'h04;
        end else begin
            valid_out <= 0;
            
            case (state)
                IDLE: begin
                    if (wr_en) begin
                        buffer[wr_ptr] <= data_in;
                        wr_ptr <= wr_ptr + 1;
                        if (wr_ptr == BUFFER_SIZE-1) begin
                            state <= READY;
                        end
                    end else if (start) begin
                        state <= SENDING;
                        rd_ptr <= 0;
                        sample_counter <= 0;
                    end
                end
                
                LOADING: begin
                    // Already handled in IDLE
                end
                
                READY: begin
                    if (start) begin
                        state <= SENDING;
                        rd_ptr <= 0;
                        sample_counter <= 0;
                    end
                end
                
                SENDING: begin
                    if (sample_counter == 0) begin
                        data_out <= buffer[rd_ptr];
                        valid_out <= 1;
                        sample_counter <= sample_counter + 1;
                    end else begin
                        valid_out <= 0;
                        sample_counter <= sample_counter + 1;
                        
                        if (sample_counter == 2'd3) begin
                            rd_ptr <= rd_ptr + 1;
                            sample_counter <= 0;
                            
                            if (rd_ptr == BUFFER_SIZE-1) begin
                                state <= IDLE;
                                rd_ptr <= 0;
                            end
                        end
                    end
                end
            endcase
        end
    end
    
endmodule