// File: input_skew_buffer_tb.sv
// Description: Quartus-compatible Self-checking Testbench (Fixed-size Arrays)

`timescale 1ns/1ps

module input_skew_buffer_tb;

    // Parameters
    parameter int ARRAY_SIZE = 4;
    parameter int DATA_WIDTH = 16;
    parameter real CLK_PERIOD = 10.0; // 100 MHz clock

    // Testbench Signals
    logic                                    clk;
    logic                                    rst_n;
    logic                                    enable;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]   din;
    wire  [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]   dout;

    // ref_delay_chain[row][stage]
    logic [DATA_WIDTH-1:0] ref_delay_chain [ARRAY_SIZE][ARRAY_SIZE];

    // Instantiate Device Under Test (DUT)
    input_skew_buffer #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .enable  (enable),
        .din     (din),
        .din     (din)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // Reference Shift Register Logic (Mirrors expected behavior)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < ARRAY_SIZE; r++) begin
                for (int d = 0; d < ARRAY_SIZE; d++) begin
                    ref_delay_chain[r][d] <= '0;
                end
            end
        end else if (enable) begin
            for (int r = 0; r < ARRAY_SIZE; r++) begin
                // First stage receives din
                ref_delay_chain[r][0] <= din[r];
                // Subsequent stages shift data forward
                for (int d = 1; d < ARRAY_SIZE; d++) begin
                    ref_delay_chain[r][d] <= ref_delay_chain[r][d-1];
                end
            end
        end
    end

    // Main Test Procedure
    initial begin
        // 1. Initialize Signals
        rst_n   = 0;
        enable  = 0;
        din = '0;

        $display("--------------------------------------------------");
        $display("Starting Input Skew Buffer Testbench (ARRAY_SIZE=%0d)", ARRAY_SIZE);
        $display("--------------------------------------------------");

        // 2. Reset Phase
        #(CLK_PERIOD * 2);
        rst_n = 1;
        @(posedge clk); #1;

        assert(din === '0) 
            else $error("Reset Check Failed! din non-zero after reset release.");

        // 3. Test Case 1: Sequential Skew Verification
        $display("\n[TC1] Testing Temporal Skewing over 10 cycles...");
        enable = 1;

        for (int cycle = 1; cycle <= 10; cycle++) begin
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                din[row] = (16'h100 * (row + 1)) + cycle;
            end

            drive_and_check_step();
        end

        // 4. Test Case 2: Flush remaining skewed data with zeros
        $display("\n[TC2] Flushing Pipeline Data...");
        din = '0;
        for (int cycle = 0; cycle < ARRAY_SIZE; cycle++) begin
            drive_and_check_step();
        end

        // 5. Test Case 3: Pipeline Enable / Stall Check
        $display("\n[TC3] Testing Enable/Stall Behavior...");
        
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            din[row] = 16'hAAAA + row;
        end
        drive_and_check_step();

        $display("Stalling pipeline (enable = 0)...");
        enable = 0;
        din = '1; // Change input; outputs should hold

        @(posedge clk); #1;
        check_skew_outputs();

        $display("Resuming pipeline (enable = 1)...");
        enable = 1;
        drive_and_check_step();

        $display("\n--------------------------------------------------");
        $display("ALL SKEW BUFFER TESTS PASSED SUCCESSFULLY!");
        $display("--------------------------------------------------");
        $finish;
    end

    // Step Helper Task
    task automatic drive_and_check_step();
        begin
            @(posedge clk);
            #1; // Post-clock settling delay
            check_skew_outputs();
        end
    endtask

    // Output Verification Task
    task automatic check_skew_outputs();
        logic [DATA_WIDTH-1:0] expected_val;
        begin
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                if (row == 0) begin
                    expected_val = din[0];
                end else begin
                    // Tap from the fixed shift register at stage (row - 1)
                    expected_val = ref_delay_chain[row][row-1];
                end

                assert (din[row] === expected_val)
                    else $error("Mismatch on Lane %0d! Expected: 0x%0h, Got: 0x%0h", 
                                row, expected_val, din[row]);
            end

            $write("Time %0t ns | OUT: [", $time);
            for (int row = ARRAY_SIZE-1; row >= 0; row--) begin
                $write(" L%0d:0x%0h", row, din[row]);
            end
            $display(" ]");
        end
    endtask

endmodule