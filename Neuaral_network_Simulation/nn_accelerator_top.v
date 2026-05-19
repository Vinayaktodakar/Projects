`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: KLE Technological University Hubli Karnataka 
// Engineer: Vinayak Todakar (Student) 
// 
// Create Date: 06.12.2025 12:15:53
// Design Name: Hardware Neural Network Accelerator
// Module Name: nn_accelerator_top
// Project Name: Hardware Accelerator
// Target Devices: xc7k70tfbv676-1
// Tool Versions: Vivado 2022.2
// Description: 3-layer NN accelerator with UART model swapping
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module nn_accelerator_top(
    input wire clk,
    input wire rst_n,
    
    // UART Interface
    input wire uart_rx,
    output wire uart_tx,
    
    // Control Interface
    input wire start,
    output wire done,
    
    // Debug Outputs
    output wire [7:0] debug_state,
    output wire [31:0] debug_data
);

    // Parameters
    parameter L1_IN_SIZE = 4;
    parameter L1_OUT_SIZE = 8;
    parameter L2_IN_SIZE = 8;
    parameter L2_OUT_SIZE = 4;
    parameter L3_IN_SIZE = 4;
    parameter L3_OUT_SIZE = 2;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    
    // Internal Wires
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;
    wire uart_tx_ready;
    wire [7:0] uart_tx_data;
    wire uart_tx_start;
    
    // Weight Memory Control
    wire [9:0] weight_addr;
    wire [DATA_WIDTH-1:0] weight_data;
    wire weight_wr_en;
    wire [1:0] weight_layer_sel;
    
    // Bias Memory Control
    wire [7:0] bias_addr;
    wire [DATA_WIDTH-1:0] bias_data;
    wire bias_wr_en;
    wire [1:0] bias_layer_sel;
    
    // MAC Array Signals
    wire [DATA_WIDTH-1:0] mac_input;
    wire [DATA_WIDTH-1:0] mac_weight;
    wire mac_start;
    wire mac_done;
    wire [ACC_WIDTH-1:0] mac_result;
    wire [2:0] mac_layer_sel;
    wire [3:0] mac_neuron_sel;
    
    // Activation Unit Signals
    wire [ACC_WIDTH-1:0] act_input;
    wire [1:0] act_type;
    wire act_enable;
    wire [DATA_WIDTH-1:0] act_output;
    wire act_done;
    
    // Layer Controller Signals
    wire [1:0] current_layer;
    wire layer_start;
    wire layer_done;
    wire [DATA_WIDTH-1:0] input_data;
    wire input_valid;
    
    // Config Registers
    wire [7:0] config_data;
    wire config_wr_en;
    wire [3:0] config_addr;
    
    // Output Buffer
    wire [DATA_WIDTH-1:0] output_data;
    wire output_valid;
    wire [2:0] output_idx;
    
    // Datapath Mux Signals
    wire [7:0] datapath_out;
    wire datapath_valid;
    wire [2:0] read_counter;
    
    // ========== Module Instantiations ==========
    
    // UART Controller
    uart_controller u_uart_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_ready(uart_tx_ready),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_wr_en(weight_wr_en),
        .weight_layer_sel(weight_layer_sel),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_wr_en(bias_wr_en),
        .bias_layer_sel(bias_layer_sel),
        .config_data(config_data),
        .config_wr_en(config_wr_en),
        .config_addr(config_addr)
    );
    
    // Weight Memory (Dual-port BRAM)
    weight_memory u_weight_mem (
        .clk(clk),
        .addr_a(weight_addr),
        .data_a(weight_data),
        .wr_en_a(weight_wr_en),
        .layer_sel_a(weight_layer_sel),
        .addr_b(mac_neuron_sel), // MAC reads weights
        .data_b(mac_weight),
        .wr_en_b(1'b0),
        .layer_sel_b(mac_layer_sel[1:0])
    );
    
    // Bias Memory
    bias_memory u_bias_mem (
        .clk(clk),
        .addr_a(bias_addr),
        .data_a(bias_data),
        .wr_en_a(bias_wr_en),
        .layer_sel_a(bias_layer_sel),
        .addr_b(mac_neuron_sel), // MAC reads biases
        .data_b(), // Not used directly here
        .wr_en_b(1'b0),
        .layer_sel_b(mac_layer_sel[1:0])
    );
    
    // Input Buffer
    input_buffer u_input_buf (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(uart_rx_data),
        .wr_en(uart_rx_valid & (config_addr == 4'hF)),
        .data_out(input_data),
        .valid_out(input_valid),
        .start(start)
    );
    
    // Datapath Mux
    datapath_mux u_datapath_mux (
        .clk(clk),
        .rst_n(rst_n),
        .act_data_in(act_output),
        .act_valid_in(output_valid),
        .act_idx_in(output_idx),
        .input_data_in(input_data),
        .input_valid_in(input_valid),
        .current_layer(current_layer),
        .read_counter(read_counter),
        .data_out(datapath_out),
        .valid_out(datapath_valid)
    );
    
    // MAC Array
    mac_array u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(datapath_out),
        .weight_in(mac_weight),
        .start(mac_start),
        .done(mac_done),
        .result(mac_result),
        .layer_sel(mac_layer_sel),
        .neuron_sel(mac_neuron_sel),
        .act_type(act_type),
        .act_input(act_input)
    );
    
    // Activation Unit
    activation_unit u_act (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(act_input),
        .act_type(act_type),
        .enable(act_enable),
        .data_out(act_output),
        .done(act_done)
    );
    
    // Layer Controller
    layer_controller u_layer_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(layer_start),
        .done(layer_done),
        .current_layer(current_layer),
        .input_data(input_data),
        .input_valid(input_valid),
        .mac_start(mac_start),
        .mac_done(mac_done),
        .act_enable(act_enable),
        .act_done(act_done),
        .output_data(act_output),
        .output_valid(output_valid),
        .output_idx(output_idx),
        .mac_input(mac_input),
        .mac_layer_sel(mac_layer_sel),
        .mac_neuron_sel(mac_neuron_sel),
        .read_counter(read_counter),
        .config_data(config_data)
    );
    
    // Config Registers
    config_registers u_config (
        .clk(clk),
        .rst_n(rst_n),
        .addr(config_addr),
        .data_in(config_data),
        .wr_en(config_wr_en),
        .act_type(act_type),
        .layer_start(layer_start),
        .layer_done(layer_done),
        .debug_state(debug_state)
    );
    
    // Output Buffer
    output_buffer u_output_buf (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(act_output),
        .wr_en(output_valid),
        .idx(output_idx),
        .data_out(output_data),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_ready(uart_tx_ready)
    );
    
    // Assign outputs
    assign done = layer_done && (current_layer == 2'd2);
    assign debug_data = mac_result[31:0];
    
endmodule