// File: output_ram.sv
// Description: Stores the computed output Matrix C.
//              Supports parallel latching from mac_array and synchronous 
//              vector/word reading for external interfaces.

module output_ram #(
    parameter int ARRAY_SIZE = 4,                         // Matrix dimension (N)
    parameter int DATA_WIDTH = 16,                        // Input width
    parameter int ACC_WIDTH  = (2 * DATA_WIDTH) + 16,     // Accumulator/Output bit-width
    parameter int DEPTH      = ARRAY_SIZE,                // Memory depth
    parameter int ADDR_WIDTH = $clog2(DEPTH)              // Address width
)(
    input  logic                                                clk,
    input  logic                                                rst_n,
    
    // Write Interface (Parallel Load from mac_array)
    input  logic                                                write_en,  // Pulse from controller when C matrix is ready
    input  logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0] c_matrix,  // Parallel grid from mac_array
    
    // Read Interface (Synchronous read for external bus/AXI)
    input  logic [ADDR_WIDTH-1:0]                               rd_addr,   // Row read address
    output logic [ARRAY_SIZE-1:0][ACC_WIDTH-1:0]                dout       // Output row vector
);

    // Memory storage: Array of row vectors
    logic [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] mem [0:DEPTH-1];

    // Sequential Write and Read Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
            dout <= '0;
        end else begin
            // Parallel capture of entire result grid from systolic array
            if (write_en) begin
                for (int r = 0; r < ARRAY_SIZE; r++) begin
                    mem[r] <= c_matrix[r];
                end
            end
            
            // Synchronous read (Infers BRAM / Output Registers cleanly in Quartus)
            dout <= mem[rd_addr];
        end
    end

endmodule