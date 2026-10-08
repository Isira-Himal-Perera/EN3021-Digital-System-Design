`timescale 1ns/1ps

module tb_matrix_multiply_top;

    // -------------------------------------------------------------------------
    // Testbench Parameters (3x3 Matrix, 8-bit Data, 20-bit Accumulator)
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
    logic [0:ARRAY_SIZE-1][DATA_WIDTH-1:0] wr_data_a;

    // Matrix B Write Interface
    logic wr_en_b;
    logic [ADDR_WIDTH-1:0] wr_addr_b;
    logic [0:ARRAY_SIZE-1][DATA_WIDTH-1:0] wr_data_b;

    // Output Memory Read Interface
    logic [ADDR_WIDTH-1:0] rd_matrix_id;
    logic [0:ARRAY_SIZE-1][ACC_WIDTH-1:0] matrix_c_out;

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
    // Waveform Dumping
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("matrix_multiply_tb.vcd");
        $dumpvars(0, tb_matrix_multiply_top);
    end

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
        // Initialize signals synchronously before reset release
        rst_n        = 0;
        start        = 0;
        wr_en_a      = 0;
        wr_addr_a    = '0;
        wr_data_a    = '0;
        wr_en_b      = 0;
        wr_addr_b    = '0;
        wr_data_b    = '0;
        rd_matrix_id = '0;

        // Step 1: Release reset on clock edge
        repeat (2) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        $display("--------------------------------------------------");
        $display("Starting Matrix Memory Write...");
        $display("--------------------------------------------------");

        // Step 2: Write Matrix A & Matrix B into RAM (1 row per clock cycle)
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            wr_en_a   <= 1'b1;
            wr_addr_a <= i[ADDR_WIDTH-1:0];
            
            wr_en_b   <= 1'b1;
            wr_addr_b <= i[ADDR_WIDTH-1:0];

            for (int j = 0; j < ARRAY_SIZE; j++) begin
                wr_data_a[j] <= matrix_a[j][i];
                wr_data_b[j] <= matrix_b[i][j];
            end
            @(posedge clk); // RAMs capture data at this rising edge
        end

        // Step 3: Disable RAM write inputs & trigger start pulse
        wr_en_a   <= 1'b0;
        wr_en_b   <= 1'b0;
        wr_addr_a <= '0;
        wr_addr_b <= '0;
        wr_data_a <= '0;
        wr_data_b <= '0;

        $display("Starting Matrix Multiplication...");
        start <= 1'b1;   // Pulse start high immediately after write completion
        @(posedge clk);  // DUT samples start=1 on this edge
        start <= 1'b0;   // Clear start signal

        // Step 4: Wait for execution to finish
        wait (done == 1'b1);
        $display("Computation Finished! Output capture done.");

        // Step 5: Read and display resulting Matrix C
        @(posedge clk);
        rd_matrix_id <= '0;
        @(posedge clk);  // Synchronous read latency wait

        $display("--------------------------------------------------");
        $display("Resulting Matrix C (3x3):");
        $display("--------------------------------------------------");
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            $write("[ ");
            rd_matrix_id = i[ADDR_WIDTH-1:0];
            #1;
            for (int j = 0; j < ARRAY_SIZE; j++) begin
                $write("%4d ", matrix_c_out[j]);
            end
            $display("]");
        end
        $display("--------------------------------------------------");

        repeat (5) @(posedge clk);
        $finish;
    end

    // // -------------------------------------------------------------------------
    // // Console Hierarchical Logging for mac_array Signals
    // // -------------------------------------------------------------------------
    // always @(posedge clk) begin
    //     if (busy) begin
    //         $display("[Time %0t ns] MAC Array Active | Inputs A=%p, B=%p | Accumulated Output C=%p",
    //                  $time,
    //                  dut.u_mac_array.a_vec,
    //                  dut.u_mac_array.b_vec,
    //                  dut.u_mac_array.c_matrix);
    //     end
    // end

endmodule