// File: mac.sv
// Description: Parameterized Multiply-Accumulate (MAC) Processing Element

module mac #(
    parameter int DATA_WIDTH = 16,                         // Width of input data A and B
    parameter int ACC_WIDTH  = (2 * DATA_WIDTH) + 4        // Width of accumulator (prevents overflow)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Control Signals
    input  logic                    clr_acc,    // Clears accumulator for a new dot-product
    input  logic                    enable,     // Clock enable for computing pipeline
    
    // Data Inputs
    input  logic [DATA_WIDTH-1:0]   a_in,
    input  logic [DATA_WIDTH-1:0]   b_in,
    
    // Systolic Forwarding Outputs (Passes inputs to adjacent PEs)
    output logic [DATA_WIDTH-1:0]   a_out,
    output logic [DATA_WIDTH-1:0]   b_out,
    
    // Accumulated Result Output
    output logic [ACC_WIDTH-1:0]    acc_out
);

    // Pipeline Registers
    logic signed [DATA_WIDTH-1:0]   a_reg, b_reg;
    logic signed [ACC_WIDTH-1:0]    acc_reg;

    // Signed multiplication product
    logic signed [2*DATA_WIDTH-1:0] mult_product;

    // Continuous assignment for multiplication logic (mapped directly to DSP blocks)
    assign mult_product = a_reg * b_reg;

    // Forwarding register outputs
    assign a_out   = a_reg;
    assign b_out   = b_reg;
    assign acc_out = acc_reg;

    // Sequential Logic: Input buffering and Accumulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg   <= '0;
            b_reg   <= '0;
            acc_reg <= '0;
        end else if (enable) begin
            // Register input values for systolic array forwarding
            a_reg <= a_in;
            b_reg <= b_in;

            // Multiply-Accumulate Logic
            if (clr_acc) begin
                // Reset accumulator to 0
                acc_reg <= '0;
            end else begin
                // Accumulate incoming product into previous total
                acc_reg <= ACC_WIDTH'(mult_product) + acc_reg;
            end
        end
    end

endmodule