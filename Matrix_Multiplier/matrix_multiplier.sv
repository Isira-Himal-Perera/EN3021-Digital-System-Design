module matrix_multiply_top #(
    parameter int ARRAY_SIZE = 7,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 16,
    parameter int RAM_DEPTH  = 16,
    parameter int ADDR_WIDTH = $clog2(RAM_DEPTH)
)(
    input  logic                                                    clk,
    input  logic                                                    rst_n,

    // Control Interface
    input  logic                                                    start,
    output logic                                                    busy,
    output logic                                                    done,

    // Input RAM Write Interface: Matrix A
    input  logic                                                    wr_en_a,
    input  logic [ADDR_WIDTH-1:0]                                   wr_addr_a,
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                   wr_data_a,

    // Input RAM Write Interface: Matrix B
    input  logic                                                    wr_en_b,
    input  logic [ADDR_WIDTH-1:0]                                   wr_addr_b,
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                   wr_data_b,

    // Output Matrix Selection & Output Interface
    input  logic [ADDR_WIDTH-1:0]                                   wr_matrix_id,
    input  logic [ADDR_WIDTH-1:0]                                   rd_matrix_id,
    output logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0]    matrix_c_out
);

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    // Controller -> Imput RAM
    logic [ADDR_WIDTH-1:0]                                  rd_addr_a;
    logic [ADDR_WIDTH-1:0]                                  rd_addr_b;
    
    // Imput RAM -> Skew buffer
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                  ram_dout_a;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                  ram_dout_b;

    // Skew buffer -> MAC Array
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                  skew_dout_a;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]                  skew_dout_b;

    // MAC Array -> Output RAM
    logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0]   mac_matrix_out;

    // Controller -> ...
    logic                                                   clear_acc;
    logic                                                   skew_en;
    logic                                                   mac_en;
    logic                                                   capture_en;

    // -------------------------------------------------------------------------
    // 1. Input Memory Instances 
    // -------------------------------------------------------------------------
    // ### Checked
    input_ram #(
        .ARRAY_SIZE (ARRAY_SIZE), 
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) u_input_ram_a (
        .clk        (clk),          
        .write_en   (wr_en_a),      
        .wr_addr    (wr_addr_a),
        .rd_addr    (rd_addr_a),
        .din        (wr_data_a),
        .dout       (ram_dout_a)
    );

    input_ram #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) u_input_ram_b (
        .clk        (clk),
        .write_en   (wr_en_b),
        .wr_addr    (wr_addr_b),
        .rd_addr    (rd_addr_b),
        .din        (wr_data_b),
        .dout       (ram_dout_b)
    );

    // -------------------------------------------------------------------------
    // 2. Input Skew Buffers (A: Row Skew, B: Column Skew)
    // -------------------------------------------------------------------------
    // ### Checked
    input_skew_buffer #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_skew_buffer_a (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (skew_en),
        .data_valid (skew_rd_en),
        .data_in    (ram_dout_a),
        .data_out   (skew_dout_a)
    );

    input_skew_buffer #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_skew_buffer_b (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (skew_en),
        .data_in    (ram_dout_b),
        .data_out   (skew_dout_b)
    );

    // -------------------------------------------------------------------------
    // 3. Central Controller FSM
    // -------------------------------------------------------------------------
    // *** Needs Debugin in this module
    matrix_controller #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_controller (
        .clk        (clk),          // 
        .rst_n      (rst_n),        // 
        .start      (start),        //
        .busy       (busy),         // 
        .done       (done),         // 
        .clear_acc  (clear_acc),    // clr_acc
        .skew_en    (skew_en),      // 
        .mem_rd_en  (mem_rd_en),    //
        .mac_en     (mac_en),       // enable
        .mem_wr_en  (capture_en),   // mem_wr_en
        .rd_addr_a  (rd_addr_a),    // ??
        .rd_addr_b  (rd_addr_b)     // ??
    );

    // -------------------------------------------------------------------------
    // 4. Systolic MAC Array
    // -------------------------------------------------------------------------
    // ### Checked
    mac_array #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_mac_array (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear_acc  (clear_acc),
        .enable     (mac_en),
        .a_vec   (skew_dout_a),
        .b_vec   (skew_dout_b),
        .c_matrix   (mac_matrix_out)
    );

    // -------------------------------------------------------------------------
    // 5. Output Parallel Memory
    // -------------------------------------------------------------------------
    // Needes debugging
    output_ram #(
        .ARRAY_SIZE   (ARRAY_SIZE),
        .ACC_WIDTH    (ACC_WIDTH),
        .DEPTH        (RAM_DEPTH)
    ) u_output_ram (
        .clk          (clk),
        .rst_n        (rst_n),
        .capture_en   (capture_en),
        .wr_matrix_id (wr_matrix_id),
        .rd_matrix_id (rd_matrix_id),
        .matrix_in    (mac_matrix_out),
        .matrix_out   (matrix_c_out)
    );

endmodule 