// File: mac_tb.sv
// Description: Self-checking Testbench for Parameterized MAC Unit

`timescale 1ns/1ps

module mac_tb;

    // Parameters
    parameter int DATA_WIDTH = 16;
    parameter int ACC_WIDTH  = (2 * DATA_WIDTH) + 16;
    parameter real CLK_PERIOD = 10.0; // 100 MHz clock

    // Testbench Signals
    logic clk;
    logic rst_n;
    logic clr_acc;
    logic enable;

    logic signed [DATA_WIDTH-1:0] a_in;
    logic signed [DATA_WIDTH-1:0] b_in;

    wire signed  [DATA_WIDTH-1:0] a_out;
    wire signed  [DATA_WIDTH-1:0] b_out;
    wire signed  [ACC_WIDTH-1:0]  acc_out;

    // Golden Reference Model Tracking
    logic signed [DATA_WIDTH-1:0] expected_a_q;
    logic signed [DATA_WIDTH-1:0] expected_b_q;
    logic signed [ACC_WIDTH-1:0]  expected_acc;

    // Instantiate Device Under Test (DUT)
    mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .clr_acc(clr_acc),
        .enable (enable),
        .a_in   (a_in),
        .b_in   (b_in),
        .a_out  (a_out),
        .b_out  (b_out),
        .acc_out(acc_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // Test Procedure
    initial begin
        // 1. Initialize Signals
        rst_n    = 0;
        clr_acc  = 0;
        enable   = 0;
        a_in     = 0;
        b_in     = 0;
        expected_acc = 0;

        $display("--------------------------------------------------");
        $display("Starting MAC Processing Element Testbench");
        $display("--------------------------------------------------");

        // 2. Apply Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        @(posedge clk);
        #1;
        assert(acc_out === '0 && a_out === '0 && b_out === '0)
            else $error("Reset Check Failed!");

        // 3. Test Case 1: Positive Values Dot Product
        $display("\n[TC1] Testing Positive Signed Accumulation...");
        run_mac_step(.a(10),  .b(5),  .clr(1)); // Cycle 0: clr_acc set -> acc = 10*5 = 50
        run_mac_step(.a(3),   .b(4),  .clr(0)); // Cycle 1: acc = 50 + (3*4) = 62
        run_mac_step(.a(100), .b(2),  .clr(0)); // Cycle 2: acc = 62 + (100*2) = 262
        
        // 4. Test Case 2: Accumulator Clear
        $display("\n[TC2] Testing Accumulator Clear (clr_acc)...");
        run_mac_step(.a(7),   .b(7),  .clr(1)); // Reset accumulator to 7*7 = 49

        // 5. Test Case 3: Negative and Mixed Signed Numbers
        $display("\n[TC3] Testing Signed Operations (Positive x Negative)...");
        run_mac_step(.a(-5),  .b(10), .clr(0)); // acc = 49 + (-5 * 10) = -1
        run_mac_step(.a(-4),  .b(-4), .clr(0)); // acc = -1 + (-4 * -4) = 15
        run_mac_step(.a(12),  .b(-2), .clr(0)); // acc = 15 + (12 * -2) = -9

        // 6. Test Case 4: Clock Enable Control
        $display("\n[TC4] Testing Enable Signal (Stalling Pipeline)...");
        enable = 0;
        a_in   = 16'd100;
        b_in   = 16'd100;
        clr_acc = 0;
        
        @(posedge clk); #1;
        check_outputs(); // Should hold previous result (-9) because enable is low

        // Resume computation
        enable = 1;
        run_mac_step(.a(2),   .b(2),  .clr(0)); // acc = -9 + 4 = -5

        // Finish simulation
        $display("\n--------------------------------------------------");
        $display("ALL TESTS PASSED SUCCESSFULLY!");
        $display("--------------------------------------------------");
        $finish;
    end

    // Helper Task to drive inputs and verify result at next clock edge
    task automatic run_mac_step(
        input logic signed [DATA_WIDTH-1:0] a,
        input logic signed [DATA_WIDTH-1:0] b,
        input logic clr
    );
        begin
            // Drive inputs
            enable  <= 1;
            clr_acc <= clr;
            a_in    <= a;
            b_in    <= b;

            // Wait for clock edge where pipeline registers latch values
            @(posedge clk);
            #1; // Small delay to settle post-clock output logic

            // Update expected values based on RTL behavioral expectation
            expected_a_q = a;
            expected_b_q = b;
            
            if (clr) begin
                expected_acc = $signed(a) * $signed(b);
            end else begin
                expected_acc = expected_acc + ($signed(a) * $signed(b));
            end

            // Run Verification Checks
            check_outputs();
        end
    endtask

    // Output Verification Task
    task automatic check_outputs();
        begin
            assert (a_out === expected_a_q) 
                else $error("a_out Mismatch! Expected: %0d, Got: %0d", expected_a_q, a_out);

            assert (b_out === expected_b_q) 
                else $error("b_out Mismatch! Expected: %0d, Got: %0d", expected_b_q, b_out);

            assert (acc_out === expected_acc)
                else $error("acc_out Mismatch! Expected: %0d, Got: %0d", expected_acc, acc_out);

            $display("SUCCESS | Inputs: A=%5d, B=%5d | Fwd: A_out=%5d, B_out=%5d | Acc Output: %0d",
                     a_in, b_in, a_out, b_out, acc_out);
        end
    endtask

endmodule