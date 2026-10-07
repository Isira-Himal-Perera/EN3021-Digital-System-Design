// File: mac_array.sv
// Description: N x N Systolic Array of MAC Units (mac.sv)

module mac_array #(
    parameter int ARRAY_SIZE = 4,                       // Grid dimension (N x N)
    parameter int DATA_WIDTH = 16,                      // Input data width
    parameter int ACC_WIDTH  = (2 * DATA_WIDTH) + 4    // Accumulator width
)(
    input  logic                                                clk,
    input  logic                                                rst_n,
    
    // Global Control Signals
    input  logic                                                clr_acc,  // Clears accumulator in all MACs
    input  logic                                                enable,   // Pipeline enable
    
    // Boundary Data Streams (Skewed vectors from input buffers)
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]               a_vec,    // Row inputs (Left boundary)
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0]               b_vec,    // Column inputs (Top boundary)
    
    // Accumulated Result Output Grid
    output logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0] c_matrix
);

    // Internal Systolic Interconnect Wires
    logic [DATA_WIDTH-1:0] horizontal_wire [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    logic [DATA_WIDTH-1:0] vertical_wire   [0:ARRAY_SIZE][0:ARRAY_SIZE-1];

    // Connect Array Boundary Inputs
    genvar r, c;
    generate
        for (r = 0; r < ARRAY_SIZE; r++) begin : gen_a_boundary
            assign horizontal_wire[r][0] = a_vec[r];
        end

        for (c = 0; c < ARRAY_SIZE; c++) begin : gen_b_boundary
            assign vertical_wire[0][c] = b_vec[c];
        end
    endgenerate

    // Instantiate N x N Grid of MAC Modules
    generate
        for (r = 0; r < ARRAY_SIZE; r++) begin : gen_row
            for (c = 0; c < ARRAY_SIZE; c++) begin : gen_col
                
                mac #(
                    .DATA_WIDTH ( DATA_WIDTH ),
                    .ACC_WIDTH  ( ACC_WIDTH  )
                ) u_mac (
                    .clk     ( clk                   ),
                    .rst_n   ( rst_n                 ),
                    .clr_acc ( clr_acc               ),
                    .enable  ( enable                ),
                    
                    .a_in    ( horizontal_wire[r][c] ),
                    .b_in    ( vertical_wire[r][c]   ),
                    
                    .a_out   ( horizontal_wire[r][c+1] ),
                    .b_out   ( vertical_wire[r+1][c]   ),
                    
                    .acc_out ( c_matrix[r][c]        )
                );

            end
        end
    endgenerate

    // Unused Boundary Net Declarations with synthesis attribute to suppress linter warnings
    (* keep *) logic [DATA_WIDTH-1:0] unused_a_out [0:ARRAY_SIZE-1];
    (* keep *) logic [DATA_WIDTH-1:0] unused_b_out [0:ARRAY_SIZE-1];

    genvar i;
    generate
        for (i = 0; i < ARRAY_SIZE; i++) begin : gen_boundary_ties
            // Route right boundary outputs
            assign unused_a_out[i] = horizontal_wire[i][ARRAY_SIZE];
            
            // Route bottom boundary outputs
            assign unused_b_out[i] = vertical_wire[ARRAY_SIZE][i];
        end
    endgenerate

endmodule