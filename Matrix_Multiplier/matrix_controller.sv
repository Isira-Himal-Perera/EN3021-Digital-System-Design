// File: matrix_controller.sv
// Description: FSM Controller that orchestrates matrix multiplication timing,
//              accumulator clears, memory read/write enablers, and status flags.

module matrix_controller #(
    parameter int ARRAY_SIZE = 4   // Matrix dimension (N)
)(
    input  logic clk,
    input  logic rst_n,
    
    // External Interface Control
    input  logic start,            // Pulse to trigger matrix multiplication
    output logic busy,             // Asserted high during computation
    output logic done,             // Single-cycle pulse when C matrix results are valid
    
    // Internal Array Control Signals
    output logic clr_acc,          // Resets MAC accumulators
    output logic enable,           // Enables MAC array and input skew registers
    
    // Memory Interface Control Signals
    output logic mem_rd_en,        // Enables reading Matrix A and B from RAM
    output logic mem_wr_en         // Enables writing Matrix C to RAM/output registers
);

    // Total computation cycles required for N x N systolic array = 3*N - 2
    localparam int TOTAL_CYCLES = 3 * ARRAY_SIZE - 2;
    localparam int COUNTER_WIDTH = $clog2(TOTAL_CYCLES + 1);

    // State Encoding
    typedef enum logic [1:0] {
        ST_IDLE    = 2'b00,
        ST_CLEAR   = 2'b01,
        ST_COMPUTE = 2'b10,
        ST_DONE    = 2'b11
    } state_t;

    state_t current_state, next_state;

    // Cycle Counter
    logic [COUNTER_WIDTH-1:0] cycle_cnt;

    // Sequential State Register & Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_IDLE;
            cycle_cnt     <= '0;
        end else begin
            current_state <= next_state;
            
            if (current_state == ST_COMPUTE) begin
                cycle_cnt <= cycle_cnt + 1'b1;
            end else begin
                cycle_cnt <= '0;
            end
        end
    end

    // Next-State Logic & Output Decoding
    always_comb begin
        // Default Assigns
        next_state = current_state;
        clr_acc   = 1'b0;
        enable    = 1'b0;
        mem_rd_en = 1'b0;
        mem_wr_en = 1'b0;
        busy      = 1'b1;
        done      = 1'b0;

        case (current_state)
            ST_IDLE: begin
                busy = 1'b0;
                if (start) begin
                    next_state = ST_CLEAR;
                end
            end

            ST_CLEAR: begin
                // Synchronously clear accumulators across all PEs
                clr_acc    = 1'b1;
                enable     = 1'b1;
                next_state = ST_COMPUTE;
            end

            ST_COMPUTE: begin
                enable    = 1'b1;
                mem_rd_en = (cycle_cnt < ARRAY_SIZE); // Stream input data for N cycles
                
                if (cycle_cnt == TOTAL_CYCLES - 1) begin
                    next_state = ST_DONE;
                end
            end

            ST_DONE: begin
                done      = 1'b1;
                busy      = 1'b0;
                mem_wr_en = 1'b1; // Output matrix C is completely computed
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

endmodule