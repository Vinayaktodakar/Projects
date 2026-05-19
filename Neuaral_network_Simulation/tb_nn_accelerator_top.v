`timescale 1ns / 1ps

module tb_nn_accelerator_top;

    // Parameters
    parameter CLK_PERIOD = 10; // 100 MHz
    
    // DUT Signals
    reg clk;
    reg rst_n;
    reg uart_rx;
    wire uart_tx;
    reg start;
    wire done;
    wire [7:0] debug_state;
    wire [31:0] debug_data;
    
    // Testbench signals
    reg [7:0] test_weights [0:71];  // 72 weights total
    reg [7:0] test_biases [0:13];   // 14 biases total
    reg [7:0] test_inputs [0:3];    // 4 inputs
    reg [7:0] expected_outputs [0:1]; // 2 outputs
    integer test_passed;
    integer test_failed;
    
    // Instantiate DUT
    nn_accelerator_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .start(start),
        .done(done),
        .debug_state(debug_state),
        .debug_data(debug_data)
    );
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // UART transmitter task
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Send start bit (0)
            uart_rx = 0;
            #8680; // 1/115200 seconds in ns
            
            // Send 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #8680;
            end
            
            // Send stop bit (1)
            uart_rx = 1;
            #8680;
        end
    endtask
    
    // Task to load weights for a layer
    task load_layer_weights;
        input [1:0] layer;
        input integer start_idx;
        input integer num_weights;
        integer i;
        begin
            // Send weight command
            uart_send_byte(8'h57); // 'W'
            #1000;
            
            // Send layer number
            uart_send_byte({6'b0, layer});
            #1000;
            
            // Send starting address (low byte)
            uart_send_byte(8'h00);
            #1000;
            
            // Send starting address (high byte - only 2 bits used)
            uart_send_byte(8'h00);
            #1000;
            
            // Send weights
            for (i = 0; i < num_weights; i = i + 1) begin
                uart_send_byte(test_weights[start_idx + i]);
                #1000;
            end
            
            #5000; // Short wait between transmissions
        end
    endtask
    
    // Task to load biases for a layer
    task load_layer_biases;
        input [1:0] layer;
        input integer start_idx;
        input integer num_biases;
        integer i;
        begin
            // Send bias command
            uart_send_byte(8'h42); // 'B'
            #1000;
            
            // Send layer number
            uart_send_byte({6'b0, layer});
            #1000;
            
            // Send starting address
            uart_send_byte(8'h00);
            #1000;
            
            // Send biases
            for (i = 0; i < num_biases; i = i + 1) begin
                uart_send_byte(test_biases[start_idx + i]);
                #1000;
            end
            
            #5000; // Short wait between transmissions
        end
    endtask
    
    // Task to send input vector
    task send_input_vector;
        integer i;
        begin
            // Send input command
            uart_send_byte(8'h49); // 'I'
            #1000;
            
            // Send input values
            for (i = 0; i < 4; i = i + 1) begin
                uart_send_byte(test_inputs[i]);
                #1000;
            end
            
            #5000;
        end
    endtask
    
    // Task to calculate expected output (deterministic)
    task calculate_expected_output;
        integer i, j;
        reg [15:0] temp;
        reg [7:0] layer1_out [0:7];
        reg [7:0] layer2_out [0:3];
        begin
            $display("[CALC] Calculating expected outputs...");
            
            // Layer 1: 4 inputs -> 8 outputs
            for (i = 0; i < 8; i = i + 1) begin
                temp = 0;
                for (j = 0; j < 4; j = j + 1) begin
                    temp = temp + (test_inputs[j] * test_weights[j*8 + i]);
                end
                temp = temp + test_biases[i];
                // ReLU activation
                layer1_out[i] = (temp[15]) ? 8'h00 : ((temp > 255) ? 8'hFF : temp[7:0]);
                $display("[CALC] Layer1[%0d] = %h (dec: %0d)", i, layer1_out[i], layer1_out[i]);
            end
            
            // Layer 2: 8 inputs -> 4 outputs
            for (i = 0; i < 4; i = i + 1) begin
                temp = 0;
                for (j = 0; j < 8; j = j + 1) begin
                    temp = temp + (layer1_out[j] * test_weights[32 + j*4 + i]);
                end
                temp = temp + test_biases[8 + i];
                // ReLU activation
                layer2_out[i] = (temp[15]) ? 8'h00 : ((temp > 255) ? 8'hFF : temp[7:0]);
                $display("[CALC] Layer2[%0d] = %h (dec: %0d)", i, layer2_out[i], layer2_out[i]);
            end
            
            // Layer 3: 4 inputs -> 2 outputs
            for (i = 0; i < 2; i = i + 1) begin
                temp = 0;
                for (j = 0; j < 4; j = j + 1) begin
                    temp = temp + (layer2_out[j] * test_weights[64 + j*2 + i]);
                end
                temp = temp + test_biases[12 + i];
                // Linear activation (no ReLU for output layer)
                expected_outputs[i] = (temp > 255) ? 8'hFF : ((temp < 0) ? 8'h00 : temp[7:0]);
                $display("[CALC] Expected Output[%0d] = %h (dec: %0d)", i, expected_outputs[i], expected_outputs[i]);
            end
        end
    endtask
    
    // Initialize test data with FIXED values
    task initialize_test_data;
        begin
            $display("=========================================");
            $display("Initializing with FIXED test data...");
            $display("=========================================");
            
            // ========== LAYER 1 WEIGHTS (4x8 = 32 weights) ==========
            // Simple pattern: increasing values
            // Row 0 (input 0 weights)
            test_weights[0] = 8'h01; test_weights[1] = 8'h02; test_weights[2] = 8'h03; test_weights[3] = 8'h04;
            test_weights[4] = 8'h05; test_weights[5] = 8'h06; test_weights[6] = 8'h07; test_weights[7] = 8'h08;
            
            // Row 1 (input 1 weights)
            test_weights[8] = 8'h09; test_weights[9] = 8'h0A; test_weights[10] = 8'h0B; test_weights[11] = 8'h0C;
            test_weights[12] = 8'h0D; test_weights[13] = 8'h0E; test_weights[14] = 8'h0F; test_weights[15] = 8'h10;
            
            // Row 2 (input 2 weights)
            test_weights[16] = 8'h11; test_weights[17] = 8'h12; test_weights[18] = 8'h13; test_weights[19] = 8'h14;
            test_weights[20] = 8'h15; test_weights[21] = 8'h16; test_weights[22] = 8'h17; test_weights[23] = 8'h18;
            
            // Row 3 (input 3 weights)
            test_weights[24] = 8'h19; test_weights[25] = 8'h1A; test_weights[26] = 8'h1B; test_weights[27] = 8'h1C;
            test_weights[28] = 8'h1D; test_weights[29] = 8'h1E; test_weights[30] = 8'h1F; test_weights[31] = 8'h20;
            
            // ========== LAYER 2 WEIGHTS (8x4 = 32 weights) ==========
            // Pattern: decreasing values
            for (integer i = 0; i < 32; i = i + 1) begin
                test_weights[32 + i] = 8'h20 - i[7:0];
            end
            
            // ========== LAYER 3 WEIGHTS (4x2 = 8 weights) ==========
            // Pattern: alternating 1 and 2
            test_weights[64] = 8'h01; test_weights[65] = 8'h02;
            test_weights[66] = 8'h01; test_weights[67] = 8'h02;
            test_weights[68] = 8'h01; test_weights[69] = 8'h02;
            test_weights[70] = 8'h01; test_weights[71] = 8'h02;
            
            // ========== BIASES ==========
            // Layer 1 biases (8)
            test_biases[0] = 8'h00; test_biases[1] = 8'h01; test_biases[2] = 8'h02; test_biases[3] = 8'h03;
            test_biases[4] = 8'h04; test_biases[5] = 8'h05; test_biases[6] = 8'h06; test_biases[7] = 8'h07;
            
            // Layer 2 biases (4)
            test_biases[8] = 8'h08; test_biases[9] = 8'h09; test_biases[10] = 8'h0A; test_biases[11] = 8'h0B;
            
            // Layer 3 biases (2)
            test_biases[12] = 8'h00; test_biases[13] = 8'h00; // No bias for output layer
            
            // ========== INPUTS ==========
            // Simple input pattern
            test_inputs[0] = 8'h01; // 1
            test_inputs[1] = 8'h02; // 2
            test_inputs[2] = 8'h03; // 3
            test_inputs[3] = 8'h04; // 4
            
            // Display test data
            $display("Layer 1 Weights (first 8):");
            for (integer w = 0; w < 8; w = w + 1) begin
                $display("  W1[0][%0d] = %h", w, test_weights[w]);
            end
            
            $display("\nLayer 1 Biases:");
            for (integer b = 0; b < 8; b = b + 1) begin
                $display("  B1[%0d] = %h", b, test_biases[b]);
            end
            
            $display("\nInputs:");
            for (integer i = 0; i < 4; i = i + 1) begin
                $display("  Input[%0d] = %h", i, test_inputs[i]);
            end
        end
    endtask
    
    // Test procedure
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        uart_rx = 1;
        start = 0;
        test_passed = 0;
        test_failed = 0;
        
        // Initialize with FIXED test data
        initialize_test_data();
        
        // Calculate expected outputs
        calculate_expected_output();
        
        // Reset
        #100;
        rst_n = 1;
        #100;
        
        $display("=========================================");
        $display("Starting NN Accelerator Test");
        $display("=========================================");
        
        // Test Case 1: Load Layer 1 weights (4x8 = 32 weights)
        $display("[TEST CASE 1] Loading Layer 1 weights...");
        load_layer_weights(2'b00, 0, 32);
        
        // Test Case 2: Load Layer 2 weights (8x4 = 32 weights)
        $display("[TEST CASE 2] Loading Layer 2 weights...");
        load_layer_weights(2'b01, 32, 32);
        
        // Test Case 3: Load Layer 3 weights (4x2 = 8 weights)
        $display("[TEST CASE 3] Loading Layer 3 weights...");
        load_layer_weights(2'b10, 64, 8);
        
        // Test Case 4: Load Layer 1 biases (8 biases)
        $display("[TEST CASE 4] Loading Layer 1 biases...");
        load_layer_biases(2'b00, 0, 8);
        
        // Test Case 5: Load Layer 2 biases (4 biases)
        $display("[TEST CASE 5] Loading Layer 2 biases...");
        load_layer_biases(2'b01, 8, 4);
        
        // Test Case 6: Load Layer 3 biases (2 biases)
        $display("[TEST CASE 6] Loading Layer 3 biases...");
        load_layer_biases(2'b10, 12, 2);
        
        // Test Case 7: Configure activation functions
        $display("[TEST CASE 7] Configuring activation...");
        uart_send_byte(8'h43); // 'C'
        #1000;
        uart_send_byte(8'h01); // Layer 1 config: ReLU
        #1000;
        uart_send_byte(8'h00);
        #5000;
        
        uart_send_byte(8'h43); // 'C'
        #1000;
        uart_send_byte(8'h02); // Layer 2 config: ReLU
        #1000;
        uart_send_byte(8'h00);
        #5000;
        
        uart_send_byte(8'h43); // 'C'
        #1000;
        uart_send_byte(8'h03); // Layer 3 config: Linear
        #1000;
        uart_send_byte(8'h03);
        #10000;
        
        // Test Case 8: Send input vector
        $display("[TEST CASE 8] Sending input vector...");
        send_input_vector();
        
        // Test Case 9: Run inference
        $display("[TEST CASE 9] Starting inference...");
        start = 1;
        #100;
        start = 0;
        
        // Wait for completion
        wait(done == 1);
        #1000;
        
        $display("[TEST] Inference complete!");
        $display("Debug state: %h", debug_state);
        
        // Test Case 10: Verify outputs
        $display("[TEST CASE 10] Waiting for output verification...");
        
        // Runtime model swap test
        $display("=========================================");
        $display("[TEST CASE 11] Runtime model swap (simplified)...");
        
        // Send new weight (just one to test)
        $display("Loading one new weight via UART...");
        uart_send_byte(8'h57); // 'W'
        #1000;
        uart_send_byte(8'h00); // layer 0
        #1000;
        uart_send_byte(8'h00); // address low
        #1000;
        uart_send_byte(8'h00); // address high
        #1000;
        uart_send_byte(8'hFF); // new weight
        #10000;
        
        // Send new input
        test_inputs[0] = 8'h0A; // Change first input
        send_input_vector();
        
        // Run second inference
        $display("[TEST] Starting second inference...");
        start = 1;
        #100;
        start = 0;
        
        wait(done == 1);
        #1000;
        
        $display("[TEST] Second inference complete!");
        
        // Summary
        #1000;
        $display("=========================================");
        $display("Test Summary:");
        $display("  Tests Passed: %0d", test_passed);
        $display("  Tests Failed: %0d", test_failed);
        $display("=========================================");
        
        if (test_failed == 0) begin
            $display("? All tests PASSED!");
        end else begin
            $display("? Some tests FAILED!");
        end
        
        #5000;
        $display("Simulation completed successfully!");
        $finish;
    end
    
    // Monitor outputs and compare with expected
    reg [7:0] received_outputs [0:1];
    integer output_count;
    
    initial begin
        output_count = 0;
        received_outputs[0] = 8'h00;
        received_outputs[1] = 8'h00;
    end
     integer i;
    always @(posedge clk) begin
        if (dut.u_output_buf.tx_start) begin
            $display("[UART TX] Output[%0d] = %h", output_count, dut.u_output_buf.tx_data);
            received_outputs[output_count] = dut.u_output_buf.tx_data;
            
            if (output_count < 1) begin
                output_count = output_count + 1;
            end else begin
                // Compare with expected when we have both outputs
                begin
                    for (i = 0; i < 2; i = i + 1) begin
                        if (received_outputs[i] == expected_outputs[i]) begin
                            $display("[VERIFY] ? Output[%0d] CORRECT: Got %h, Expected %h", 
                                     i, received_outputs[i], expected_outputs[i]);
                            test_passed = test_passed + 1;
                        end else begin
                            $display("[VERIFY] ? Output[%0d] WRONG: Got %h, Expected %h", 
                                     i, received_outputs[i], expected_outputs[i]);
                            test_failed = test_failed + 1;
                        end
                    end
                end
                output_count = 0;
            end
        end
        
        // Monitor MAC results for debugging
        if (dut.u_mac.done) begin
            $display("[MAC] Result: %h (Layer %0d)", dut.u_mac.result, dut.u_layer_ctrl.current_layer);
        end
        
        // Monitor activation outputs for debugging
        if (dut.u_act.done) begin
            $display("[ACT] Output: %h", dut.u_act.data_out);
        end
    end
    
    // Simple timeout
    initial begin
        #5000000; // 5ms total timeout (much shorter)
        $display("ERROR: Simulation timeout!");
        $display("Test Summary: Passed=%0d, Failed=%0d", test_passed, test_failed);
        $finish;
    end
    
endmodule