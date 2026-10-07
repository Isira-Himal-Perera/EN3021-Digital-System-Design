`timescale 1ns/1ps

module tb_matrix_multiply_top;

    // -------------------------------------------------------------------------
    // Testbench Parameters (3x3 Matrix, 8-bit Data, 16-bit Accumulator)
    // -------------------------------------------------------------------------
    localparam int ARRAY_SIZE = 3;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH  = 20;
    localparam int ADDR_WIDTH = $clog2(ARRAY_SIZE);

    // Clock period (100 MHz)
    localparam time CLK_PERIOD = 10ns;

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
    logic [ADDR_WIDTH-1:0] wr_addr_a;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] wr_data_a;

    // Matrix B Write Interface
    logic wr_en_b;
    logic [ADDR_WIDTH-1:0] wr_addr_b;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] wr_data_b;

    // Output Memory Read Interface
    logic [ADDR_WIDTH-1:0] rd_matrix_id;
    logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0] matrix_c_out;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    matrix_multiplier #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .busy          (busy),
        .done          (done),
        .wr_en_a       (wr_en_a),
        .wr_addr_a     (wr_addr_a),
        .wr_data_a     (wr_data_a),
        .wr_en_b       (wr_en_b),
        .wr_addr_b     (wr_addr_b),
        .wr_data_b     (wr_data_b),
        .rd_matrix_id  (rd_matrix_id),
        .matrix_c_out  (matrix_c_out)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Test Matrices Definition
    // Matrix A:          Matrix B:          Expected C = A * B:
    // [ 1  2  3 ]        [ 9  8  7 ]        [ 30  24  18 ]
    // [ 4  5  6 ]   *    [ 6  5  4 ]   =    [ 84  69  54 ]
    // [ 7  8  9 ]        [ 3  2  1 ]        [138 114  90 ]
    // -------------------------------------------------------------------------
    byte matrix_a[3][3] = '{
        '{8'd1, 8'd2, 8'd3},
        '{8'd4, 8'd5, 8'd6},
        '{8'd7, 8'd8, 8'd9}
    };

    byte matrix_b[3][3] = '{
        '{8'd9, 8'd8, 8'd7},
        '{8'd6, 8'd5, 8'd4},
        '{8'd3, 8'd2, 8'd1}
    };

    // -------------------------------------------------------------------------
    // Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        // Initialize signals
        rst_n        = 0;
        start        = 0;
        wr_en_a      = 0;
        wr_addr_a    = '0;
        wr_data_a    = '0;
        wr_en_b      = 0;
        wr_addr_b    = '0;
        wr_data_b    = '0;
        rd_matrix_id = '0;

        // Step 1: Apply and release Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        $display("--------------------------------------------------");
        $display("Starting Matrix Memory Write...");
        $display("--------------------------------------------------");

        // Step 2: Write Matrix A & Matrix B into RAM
        // Assuming RAM stores one matrix row per address:
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            @(posedge clk);
            wr_en_a   <= 1'b1;
            wr_addr_a <= i[ADDR_WIDTH-1:0];
            
            wr_en_b   <= 1'b1;
            wr_addr_b <= i[ADDR_WIDTH-1:0];

            for (int j = 0; j < ARRAY_SIZE; j++) begin
                wr_data_a[j] <= matrix_a[i][j];
                wr_data_b[j] <= matrix_b[i][j];
            end
        end

        @(posedge clk);
        wr_en_a <= 1'b0;
        wr_en_b <= 1'b0;
        #(CLK_PERIOD);

        // Step 3: Trigger Multiplication
        $display("Starting Matrix Multiplication...");
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        // Step 4: Wait for execution to finish
        wait (done == 1'b1);
        $display("Computation Finished! Output capture done.");

        // Step 5: Read and display resulting Matrix C
        @(posedge clk);
        rd_matrix_id <= '0; // Address 0
        #(CLK_PERIOD);      // Wait for output memory read latency

        $display("--------------------------------------------------");
        $display("Resulting Matrix C (3x3):");
        $display("--------------------------------------------------");
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            $write("[ ");
            for (int j = 0; j < ARRAY_SIZE; j++) begin
                $write("%4d ", matrix_c_out[i][j]);
            end
            $display("]");
        end
        $display("--------------------------------------------------");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule