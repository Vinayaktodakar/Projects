`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.12.2025 12:14:54
// Design Name: 
// Module Name: uart_controller
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


module uart_controller(
    input wire clk,
    input wire rst_n,
    
    // UART Physical Interface
    input wire uart_rx,
    output reg uart_tx,
    
    // UART Data Interface
    output reg [7:0] rx_data,
    output reg rx_valid,
    input wire [7:0] tx_data,
    input wire tx_start,
    output wire tx_ready,
    
    // Weight Memory Interface
    output reg [9:0] weight_addr,
    output reg [7:0] weight_data,
    output reg weight_wr_en,
    output reg [1:0] weight_layer_sel,
    
    // Bias Memory Interface
    output reg [7:0] bias_addr,
    output reg [7:0] bias_data,
    output reg bias_wr_en,
    output reg [1:0] bias_layer_sel,
    
    // Config Register Interface
    output reg [7:0] config_data,
    output reg config_wr_en,
    output reg [3:0] config_addr
);

    // UART Parameters (115200 baud @ 100MHz)
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter BAUD_COUNT = CLK_FREQ / BAUD_RATE;
    
    // States
    localparam [3:0]
        IDLE        = 4'd0,
        RX_START    = 4'd1,
        RX_DATA     = 4'd2,
        RX_STOP     = 4'd3,
        TX_START    = 4'd4,
        TX_DATA     = 4'd5,
        TX_STOP     = 4'd6,
        CMD_DECODE  = 4'd7,
        LOAD_WEIGHT = 4'd8,
        LOAD_BIAS   = 4'd9,
        LOAD_CONFIG = 4'd10;
    
    // UART Commands
    localparam [7:0]
        CMD_WEIGHT  = 8'h57, // 'W'
        CMD_BIAS    = 8'h42, // 'B'
        CMD_CONFIG  = 8'h43, // 'C'
        CMD_INPUT   = 8'h49, // 'I'
        CMD_RUN     = 8'h52; // 'R'
    
    reg [3:0] state;
    reg [15:0] baud_counter;
    reg [2:0] bit_counter;
    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;
    reg tx_busy;
    
    // Address counters
    reg [9:0] weight_addr_cnt;
    reg [7:0] bias_addr_cnt;
    reg [1:0] layer_cnt;
    reg [15:0] byte_cnt;
    
    // Command register
    reg [7:0] cmd_reg;
    
    // Assign outputs
    assign tx_ready = ~tx_busy;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            baud_counter <= 0;
            bit_counter <= 0;
            tx_shift_reg <= 8'hFF;
            rx_shift_reg <= 0;
            uart_tx <= 1'b1;
            tx_busy <= 0;
            rx_valid <= 0;
            rx_data <= 0;
            
            weight_addr <= 0;
            weight_data <= 0;
            weight_wr_en <= 0;
            weight_layer_sel <= 0;
            
            bias_addr <= 0;
            bias_data <= 0;
            bias_wr_en <= 0;
            bias_layer_sel <= 0;
            
            config_data <= 0;
            config_wr_en <= 0;
            config_addr <= 0;
            
            weight_addr_cnt <= 0;
            bias_addr_cnt <= 0;
            layer_cnt <= 0;
            byte_cnt <= 0;
            cmd_reg <= 0;
        end else begin
            // Default values
            weight_wr_en <= 0;
            bias_wr_en <= 0;
            config_wr_en <= 0;
            rx_valid <= 0;
            uart_tx <= 1'b1;
            
            case (state)
                IDLE: begin
                    if (!uart_rx) begin // Start bit detected
                        state <= RX_START;
                        baud_counter <= BAUD_COUNT/2;
                        bit_counter <= 0;
                    end else if (tx_start && tx_ready) begin
                        state <= TX_START;
                        tx_shift_reg <= tx_data;
                        tx_busy <= 1;
                        baud_counter <= BAUD_COUNT;
                        bit_counter <= 0;
                        uart_tx <= 0; // Start bit
                    end
                end
                
                RX_START: begin
                    if (baud_counter == 0) begin
                        state <= RX_DATA;
                        baud_counter <= BAUD_COUNT;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                RX_DATA: begin
                    if (baud_counter == 0) begin
                        rx_shift_reg[bit_counter] <= uart_rx;
                        bit_counter <= bit_counter + 1;
                        baud_counter <= BAUD_COUNT;
                        
                        if (bit_counter == 7) begin
                            state <= RX_STOP;
                        end
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                RX_STOP: begin
                    if (baud_counter == 0) begin
                        state <= CMD_DECODE;
                        rx_data <= rx_shift_reg;
                        rx_valid <= 1;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                CMD_DECODE: begin
                    case (rx_shift_reg)
                        CMD_WEIGHT: begin
                            state <= LOAD_WEIGHT;
                            cmd_reg <= CMD_WEIGHT;
                            byte_cnt <= 0;
                        end
                        CMD_BIAS: begin
                            state <= LOAD_BIAS;
                            cmd_reg <= CMD_BIAS;
                            byte_cnt <= 0;
                        end
                        CMD_CONFIG: begin
                            state <= LOAD_CONFIG;
                            cmd_reg <= CMD_CONFIG;
                            byte_cnt <= 0;
                        end
                        default: begin
                            state <= IDLE;
                        end
                    endcase
                end
                
                LOAD_WEIGHT: begin
                    if (rx_valid) begin
                        case (byte_cnt)
                            0: layer_cnt <= rx_data[1:0];
                            1: weight_addr_cnt[7:0] <= rx_data;
                            2: begin
                                weight_addr_cnt[9:8] <= rx_data[1:0];
                                byte_cnt <= byte_cnt + 1;
                            end
                            default: begin
                                weight_data <= rx_data;
                                weight_addr <= weight_addr_cnt;
                                weight_layer_sel <= layer_cnt;
                                weight_wr_en <= 1;
                                weight_addr_cnt <= weight_addr_cnt + 1;
                                
                                if (weight_addr_cnt == 10'h3FF) begin
                                    state <= IDLE;
                                end
                            end
                        endcase
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
                LOAD_BIAS: begin
                    if (rx_valid) begin
                        case (byte_cnt)
                            0: layer_cnt <= rx_data[1:0];
                            1: bias_addr_cnt <= rx_data;
                            default: begin
                                bias_data <= rx_data;
                                bias_addr <= bias_addr_cnt;
                                bias_layer_sel <= layer_cnt;
                                bias_wr_en <= 1;
                                bias_addr_cnt <= bias_addr_cnt + 1;
                                
                                if (bias_addr_cnt == 8'hFF) begin
                                    state <= IDLE;
                                end
                            end
                        endcase
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
                LOAD_CONFIG: begin
                    if (rx_valid) begin
                        case (byte_cnt)
                            0: config_addr <= rx_data[3:0];
                            default: begin
                                config_data <= rx_data;
                                config_wr_en <= 1;
                                state <= IDLE;
                            end
                        endcase
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
                TX_START: begin
                    if (baud_counter == 0) begin
                        state <= TX_DATA;
                        baud_counter <= BAUD_COUNT;
                        uart_tx <= tx_shift_reg[0];
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                TX_DATA: begin
                    if (baud_counter == 0) begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                        baud_counter <= BAUD_COUNT;
                        uart_tx <= tx_shift_reg[1];
                        
                        if (bit_counter == 7) begin
                            state <= TX_STOP;
                            uart_tx <= 1'b1; // Stop bit
                        end
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                TX_STOP: begin
                    if (baud_counter == 0) begin
                        state <= IDLE;
                        tx_busy <= 0;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule