`timescale 1ns/1ps

module mini_cnn_pe_tb;

    // Parameters
    localparam WIN_SIZE  = 9;
    localparam MEM_DEPTH = 18;
    localparam DATA_W    = 8;
    localparam OUT_W     = 32;

    // DUT signals
    reg clk;
    reg rst;
    reg signed [DATA_W-1:0] data_in;
    reg [1:0] mode;
    reg start;
    wire done;
    wire signed [OUT_W-1:0] result;

    // Instantiate DUT
    mini_cnn_pe #(
        .WIN_SIZE(WIN_SIZE),
        .MEM_DEPTH(MEM_DEPTH),
        .DATA_W(DATA_W),
        .OUT_W(OUT_W),
        .DEBUG(0)
    ) uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .mode(mode),
        .start(start),
        .done(done),
        .result(result)
    );

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Variables
    integer i, tcase;
    reg signed [7:0] input_pixels [0:8];
    reg signed [7:0] kernel_values [0:8];

    // Reset task
    task apply_reset;
    begin
        rst = 1;
        start = 0;
        data_in = 0;
        mode = 0;
        #20;
        rst = 0;
        #20;
    end
    endtask

    // Load pixels + kernel data into DUT memory
    task load_data;
    begin
        start = 1;
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            if (i < WIN_SIZE)
                data_in = input_pixels[i];
            else
                data_in = kernel_values[i - WIN_SIZE];
            #10;
        end
        start = 0;
        #10;
    end
    endtask

    // Print pixel + kernel data
    task print_data;
    begin
        $display("  Input Pixels (W):");
        $display("   %0d  %0d  %0d", input_pixels[0], input_pixels[1], input_pixels[2]);
        $display("   %0d  %0d  %0d", input_pixels[3], input_pixels[4], input_pixels[5]);
        $display("   %0d  %0d  %0d", input_pixels[6], input_pixels[7], input_pixels[8]);
        $display("  Kernel (K):");
        $display("   %0d  %0d  %0d", kernel_values[0], kernel_values[1], kernel_values[2]);
        $display("   %0d  %0d  %0d", kernel_values[3], kernel_values[4], kernel_values[5]);
        $display("   %0d  %0d  %0d", kernel_values[6], kernel_values[7], kernel_values[8]);
    end
    endtask

    // Define positive test cases
    task set_test_vectors(input integer case_id);
    begin
        case (case_id)

            // ------------------------------------------------------
            0: begin // Pixels increasing 1..9, kernel all 1s
                for (i=0; i<9; i=i+1) begin
                    input_pixels[i] = i + 1;
                    kernel_values[i] = 1;
                end
            end

            // ------------------------------------------------------
            1: begin // Pixels 2..10, kernel 1..9
                for (i=0; i<9; i=i+1) begin
                    input_pixels[i] = i + 2;
                    kernel_values[i] = 0;
                end
            end

            // ------------------------------------------------------
            2: begin // Pixels 3..11, kernel all 2s
                for (i=0; i<9; i=i+1) begin
                    input_pixels[i] = i + 3;
                    kernel_values[i] = 2;
                end
            end

            // ------------------------------------------------------
            3: begin // Pixels 1..9, center-weighted kernel
                input_pixels[0]=1; input_pixels[1]=2; input_pixels[2]=3;
                input_pixels[3]=4; input_pixels[4]=5; input_pixels[5]=6;
                input_pixels[6]=7; input_pixels[7]=8; input_pixels[8]=9;

                kernel_values[0]=1; kernel_values[1]=1; kernel_values[2]=1;
                kernel_values[3]=1; kernel_values[4]=1; kernel_values[5]=5;
                kernel_values[6]=1; kernel_values[7]=1; kernel_values[8]=1;
            end

            default: begin
                for (i=0; i<9; i=i+1) begin
                    input_pixels[i]=0;
                    kernel_values[i]=0;
                end
            end
        endcase
    end
    endtask

    // -------------------- MAIN TEST SEQUENCE --------------------
    initial begin
        clk = 0;
        apply_reset;

        for (tcase = 0; tcase < 4; tcase = tcase + 1) begin
            $display("\n============================================");
            $display(" Test Case %0d @ time %0t ns", tcase, $time);
            set_test_vectors(tcase);
            print_data();

            // --- Mode 00: ReLU ---
            mode = 2'b00;
            $display(" Running Mode 00 (ReLU)...");
            load_data;
            wait(done);
            #10;
            $display("  -> Result = %0d", result);

            // --- Mode 01: MaxPool ---
            apply_reset;
            mode = 2'b01;
            $display(" Running Mode 01 (MaxPool)...");
            load_data;
            wait(done);
            #10;
            $display("  -> Result = %0d", result);

            // --- Mode 10: Raw Accumulation ---
            apply_reset;
            mode = 2'b10;
            $display(" Running Mode 10 (Raw Accumulation)...");
            load_data;
            wait(done);
            #10;
            $display("  -> Result = %0d", result);

            $display("============================================");
            #100;
        end

        $display("\n? All positive test cases completed at time %0t ns", $time);
        $finish;
    end

endmodule