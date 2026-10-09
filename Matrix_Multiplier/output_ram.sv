// File: output_ram.sv
// Description: Stores the computed output Matrix C.
//              Supports parallel latching from mac_array and synchronous 
//              vector/word reading for external interfaces.

module output_ram #(
    parameter int ARRAY_SIZE = 7,                   // Matrix dimension (N)
    parameter int ACC_WIDTH  = 36,                  // Accumulator/Output bit-width
    parameter int ADDR_WIDTH = $clog2(ARRAY_SIZE)   // Address width
)(
    input  logic                                                clk,
    input  logic                                                rst_n,

    // Write Interface (Parallel Load from mac_array)
    input  logic                                                write_en,   // Pulse from controller when C matrix is ready
    input  logic [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1][ACC_WIDTH-1:0] c_matrix,   // Parallel grid from mac_array

    // Read Interface (Synchronous read for external bus/AXI)
    input  logic [ADDR_WIDTH-1:0]                               rd_addr,    // Row read address
    output logic [0:ARRAY_SIZE-1][ACC_WIDTH-1:0]                dout        // Output row vector
);

    // Memory storage: Array of row vectors
    logic [0:ARRAY_SIZE-1][ACC_WIDTH-1:0] mem [0:ARRAY_SIZE-1];

    // Sequential Write and Read Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                mem[i] <= '0;
            end
        end else begin
            // Parallel capture of entire result grid from systolic array
            if (write_en) begin
                for (int r = 0; r < ARRAY_SIZE; r++) begin
                    mem[r] <= c_matrix[r];
                end
            end
        end
    end

    assign dout = mem[rd_addr];

endmodule