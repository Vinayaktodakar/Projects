`timescale 1ns/1ps
module mini_cnn_pe #(
    parameter WIN_SIZE  = 9,
    parameter MEM_DEPTH = 18,
    parameter DATA_W    = 8,
    parameter OUT_W     = 32,
    parameter DEBUG     = 1
)(
    input               clk,
    input               rst,
    input  signed [DATA_W-1:0] data_in,
    input        [1:0]  mode,
    input               start,
    output reg          done,
    output reg signed [OUT_W-1:0] result
);

    // FSM states
    reg [3:0] state;
    localparam IDLE         = 0,
               LOAD         = 1,
               COMPUTE_INIT = 2,
               PRIME_READ   = 3,
               READ_W       = 4,
               WAIT_W       = 5,
               READ_K       = 6,
               WAIT_K       = 7,
               DONE         = 8;

    // Internal registers
    reg [4:0] load_cnt, compute_idx;
    reg [4:0] mem_addr;
    reg       mem_we;
    reg signed [DATA_W-1:0] mem_wdata;
    wire signed [DATA_W-1:0] mem_rdata;

    // Datapath
    reg signed [DATA_W-1:0] buffer_w;
    reg signed [OUT_W-1:0] acc, max_val;
    wire signed [OUT_W-1:0] prod;

    // Multiply
    wire signed [15:0] mul_a = { {8{buffer_w[7]}}, buffer_w };
    wire signed [15:0] mul_b = { {8{mem_rdata[7]}}, mem_rdata };
    assign prod = mul_a * mul_b;

    // RAM instance
    rpt_spram #(
        .ADDR_W(5),
        .DEPTH(MEM_DEPTH),
        .DATA_W(DATA_W)
    ) u_ram (
        .clk(clk),
        .we(mem_we),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .rdata(mem_rdata)
    );

    // FSM
    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            load_cnt    <= 0;
            compute_idx <= 0;
            mem_we      <= 0;
            mem_addr    <= 0;
            done        <= 0;
            acc         <= 0;
            buffer_w    <= 0;
            max_val     <= -32'sd2147483648;
            result      <= 0;
        end else begin
            done <= 0;

            case (state)
            //------------------------------------
            IDLE: begin
                if (start) begin
                    load_cnt <= 0;
                    mem_we   <= 1;
                    mem_addr <= 0;
                    state    <= LOAD;
                end
            end

            //------------------------------------
            LOAD: begin
                mem_we    <= 1;
                mem_wdata <= data_in;
                mem_addr  <= load_cnt;

                if (load_cnt == MEM_DEPTH - 1) begin
                    mem_we   <= 0;
                    state    <= COMPUTE_INIT;
                end else begin
                    load_cnt <= load_cnt + 1;
                end
            end

            //------------------------------------
            COMPUTE_INIT: begin
                compute_idx <= 0;
                acc         <= 0;
                max_val     <= -32'sd2147483648;
                buffer_w    <= 0;
                mem_we      <= 0;
                // Prime first read (W[0])
                mem_addr    <= 0;
                state       <= PRIME_READ;
            end

            //------------------------------------
            PRIME_READ: begin
                // After this cycle, mem_rdata = W[0]
                buffer_w <= mem_rdata;
                mem_addr <= WIN_SIZE; // read K[0]
                state    <= WAIT_K;
            end

            //------------------------------------
            READ_W: begin
                mem_addr <= compute_idx; // read next W
                state    <= WAIT_W;
            end

            //------------------------------------
            WAIT_W: begin
                buffer_w <= mem_rdata;
                mem_addr <= WIN_SIZE + compute_idx;
                state    <= WAIT_K;
            end

            //------------------------------------
            WAIT_K: begin
                // compute
                acc <= acc + prod;
                if (prod > max_val)
                    max_val <= prod;

                if (DEBUG)
                    $display("Cycle %0t: W[%0d]=%0d, K[%0d]=%0d, Prod=%0d, Acc=%0d",
                              $time, compute_idx, buffer_w, compute_idx, mem_rdata, prod, acc);

                compute_idx <= compute_idx + 1;

                if (compute_idx == WIN_SIZE)
                    state <= DONE;
                else
                    state <= READ_W;
            end

            //------------------------------------
            DONE: begin
                case (mode)
                    2'b00: result <= (acc < 0) ? 0 : acc; // ReLU
                    2'b01: result <= max_val;             // MaxPool
                    2'b10: result <= acc;                 // Raw Acc
                    default: result <= acc;
                endcase
                done  <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
            endcase
        end
    end
endmodule
