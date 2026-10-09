// File: tb_matrix_multiply_random.sv
// Description: Self-checking, randomized testbench for top-level matrix_multiplier.

`timescale 1ns/1ps

module tb_matrix_multiply_random;

    // -------------------------------------------------------------------------
    // Testbench Parameters
    // -------------------------------------------------------------------------
    parameter int ARRAY_SIZE = 7;
    parameter int DATA_WIDTH = 8;
    parameter int ACC_WIDTH  = (2 * DATA_WIDTH) + $clog2(ARRAY_SIZE);
    parameter int ADDR_WIDTH = $clog2(ARRAY_SIZE);

    // Number of random matrix multiplication tests to perform
    parameter int NUM_TESTS  = 50;

    // Clock period (100 MHz)
    parameter time CLK_PERIOD = 10ns;

    // -------------------------------------------------------------------------
    // DUT Interface Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    // Control Interface
    logic start;
    logic busy;
    logic done;

    // Matrix A Write Interface
    logic wr_en_a;
    logic [ADDR_WIDTH-1:0]                wr_addr_a;
    logic [0:ARRAY_SIZE-1][DATA_WIDTH-1:0] wr_data_a;

    // Matrix B Write Interface
    logic wr_en_b;
    logic [ADDR_WIDTH-1:0]                wr_addr_b;
    logic [0:ARRAY_SIZE-1][DATA_WIDTH-1:0] wr_data_b;

    // Output Memory Read Interface
    logic [ADDR_WIDTH-1:0]                rd_matrix_id;
    logic [0:ARRAY_SIZE-1][ACC_WIDTH-1:0] matrix_c_out;

    // -------------------------------------------------------------------------
    // Data Types for Software Golden Model
    // -------------------------------------------------------------------------
    typedef logic signed [DATA_WIDTH-1:0] matrix_in_t  [ARRAY_SIZE][ARRAY_SIZE];
    typedef logic signed [ACC_WIDTH-1:0]  matrix_out_t [ARRAY_SIZE][ARRAY_SIZE];

    // Global Statistics
    int total_errors = 0;
    int pass_count   = 0;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    matrix_multiplier #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .busy         (busy),
        .done         (done),
        .wr_en_a      (wr_en_a),
        .wr_addr_a    (wr_addr_a),
        .wr_data_a    (wr_data_a),
        .wr_en_b      (wr_en_b),
        .wr_addr_b    (wr_addr_b),
        .wr_data_b    (wr_data_b),
        .rd_matrix_id (rd_matrix_id),
        .matrix_c_out (matrix_c_out)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Waveform Dumping
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("matrix_multiply_random_tb.vcd");
        $dumpvars(0, tb_matrix_multiply_random);
    end

    // -------------------------------------------------------------------------
    // Software Golden Reference Model Computation
    // -------------------------------------------------------------------------
    function automatic matrix_out_t compute_golden_c(
        input matrix_in_t mat_a,
        input matrix_in_t mat_b
    );
        matrix_out_t golden;
        for (int r = 0; r < ARRAY_SIZE; r++) begin
            for (int c = 0; c < ARRAY_SIZE; c++) begin
                golden[r][c] = '0;
                for (int k = 0; k < ARRAY_SIZE; k++) begin
                    golden[r][c] += $signed(mat_a[r][k]) * $signed(mat_b[k][c]);
                end
            end
        end
        return golden;
    endfunction

    // -------------------------------------------------------------------------
    // Helper Task: Randomize Input Matrices
    // -------------------------------------------------------------------------
    task automatic randomize_matrices(
        output matrix_in_t mat_a,
        output matrix_in_t mat_b
    );
        for (int r = 0; r < ARRAY_SIZE; r++) begin
            for (int c = 0; c < ARRAY_SIZE; c++) begin
                mat_a[r][c] = $urandom_range(0, (1 << DATA_WIDTH) - 1);
                mat_b[r][c] = $urandom_range(0, (1 << DATA_WIDTH) - 1);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper Task: Reset DUT
    // -------------------------------------------------------------------------
    task automatic reset_dut();
        rst_n        <= 1'b0;
        start        <= 1'b0;
        wr_en_a      <= 1'b0;
        wr_addr_a    <= '0;
        wr_data_a    <= '0;
        wr_en_b      <= 1'b0;
        wr_addr_b    <= '0;
        wr_data_b    <= '0;
        rd_matrix_id <= '0;

        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Task: Execute Single Test Iteration
    // -------------------------------------------------------------------------
    task automatic run_single_test(input int test_idx);
        matrix_in_t  test_a;
        matrix_in_t  test_b;
        matrix_out_t golden_c;
        bit          test_failed = 0;

        // 1. Generate Random Input Data & Compute Golden Model
        randomize_matrices(test_a, test_b);
        golden_c = compute_golden_c(test_a, test_b);

        // 2. Write Matrix A and Matrix B into Input RAMs
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            wr_en_a   <= 1'b1;
            wr_addr_a <= i[ADDR_WIDTH-1:0];

            wr_en_b   <= 1'b1;
            wr_addr_b <= i[ADDR_WIDTH-1:0];

            for (int j = 0; j < ARRAY_SIZE; j++) begin
                wr_data_a[j] <= test_a[j][i];
                wr_data_b[j] <= test_b[i][j];
            end
            @(posedge clk);
        end

        // 3. Clear Write Interface and Pulse Start
        wr_en_a   <= 1'b0;
        wr_en_b   <= 1'b0;
        wr_addr_a <= '0;
        wr_addr_b <= '0;
        wr_data_a <= '0;
        wr_data_b <= '0;

        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        // 4. Wait for Multiplication Completion
        wait (done == 1'b1);
        repeat (2) @(posedge clk);

        // 5. Read back Output Matrix and Verify Against Golden Model
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            rd_matrix_id = i[ADDR_WIDTH-1:0];
            #1; // Settling time for combinational RAM output

            for (int j = 0; j < ARRAY_SIZE; j++) begin
                if (matrix_c_out[j] !== golden_c[i][j]) begin
                    $error("[TEST %0d FAILED] Row %0d, Col %0d | Expected: %0d, Got: %0d",
                           test_idx, i, j, $signed(golden_c[i][j]), $signed(matrix_c_out[j]));
                    test_failed = 1;
                    total_errors++;
                end
            end
            @(posedge clk);
        end

        if (!test_failed) begin
            pass_count++;
            $display("[TEST %02d PASSED] Output matches golden model.", test_idx);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("==================================================");
        $display(" Starting Randomized Matrix Multiplier Tests");
        $display(" Total Tests: %0d | Array Size: %0dx%0d", NUM_TESTS, ARRAY_SIZE, ARRAY_SIZE);
        $display("==================================================");

        reset_dut();

        for (int t = 1; t <= NUM_TESTS; t++) begin
            run_single_test(t);
        end

        $display("==================================================");
        $display(" TEST SUMMARY");
        $display(" Total Tests Run: %0d", NUM_TESTS);
        $display(" Passed:          %0d", pass_count);
        $display(" Failed:          %0d", total_errors);
        $display("==================================================");

        if (total_errors == 0) begin
            $display(">>> ALL RANDOM TESTS PASSED SUCCESSFULY! <<<");
        end else begin
            $display(">>> TEST SUITE FAILED WITH %0d MISMATCHES! <<<", total_errors);
        end
        @(posedge clk);

        $finish;
    end

endmodule