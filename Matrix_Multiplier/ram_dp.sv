// File: input_ram.sv
// Description: Dual-port vector RAM for storing input Matrices A and B.
//              Provides single-cycle row/column vector access to prevent array stalls.

module input_ram #(
    parameter int ARRAY_SIZE = 4,                  // Matrix dimension / Vector width
    parameter int DATA_WIDTH = 16,                 // Bit-width per data element
    parameter int DEPTH      = ARRAY_SIZE,         // Memory depth (number of rows/columns)
    parameter int ADDR_WIDTH = $clog2(DEPTH)       // Calculated address width
)(
    input  logic                         clk,
    
    // Write Interface (Single-cycle vector load)
    input  logic                         write_en,  // Write enable flag
    input  logic [ADDR_WIDTH-1:0]        wr_addr,   // Write row/column address
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] din,       // Packed vector input data
    
    // Read Interface (Streams directly into skew buffers)
    input  logic [ADDR_WIDTH-1:0]        rd_addr,   // Read row/column address
    output logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] dout       // Packed vector output data
);

    // Memory array: Depth array of N-element packed vectors
    // Quartus Prime will infer Block RAM (BRAM) for this structure
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Synchronous Read/Write Logic
    always_ff @(posedge clk) begin
        if (write_en) begin
            mem[wr_addr] <= din;
        end
        // Synchronous read registered on clock edge for BRAM synthesis compatibility
        dout <= mem[rd_addr]; 
    end

endmodule