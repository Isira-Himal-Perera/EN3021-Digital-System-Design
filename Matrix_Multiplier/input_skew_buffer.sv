// File: input_skew_buffer.sv
// Description: Staggers/skews input vectors temporally using shift register pipelines
//              to align data flow across the 2D Systolic Array. Features an active-low 
//              data_valid / zeroing control signal.

module input_skew_buffer #(
    parameter int ARRAY_SIZE = 4,   // Number of rows/columns (N)
    parameter int DATA_WIDTH = 16   // Bit-width of input data
)(
    input  logic                                 clk,
    input  logic                                 rst_n,
    input  logic                                 enable,     // Pipeline control
    input  logic                                 mem_rd_en, // When low (0), inputs are forced to 0
    
    // Parallel un-skewed input vector from BRAM/Buffers
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] din,
    
    // Time-skewed output vector fed directly into mac_array
    output logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] dout
);

    // Gated input data vector based on the mem_rd_en signal
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] effective_data_in;

    // Direct zeros into the pipeline when mem_rd_en is 0
    assign effective_data_in = mem_rd_en ? din : '0;

    genvar i;
    generate
        for (i = 0; i < ARRAY_SIZE; i++) begin : gen_skew_line
            
            if (i == 0) begin : gen_no_delay
                // Row/Col 0 requires 0 cycles delay
                assign dout[0] = effective_data_in[0];
            end else begin : gen_delay_chain
                // Row/Col i requires a shift register chain of depth 'i'
                logic [DATA_WIDTH-1:0] shift_reg [0:i-1];

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int k = 0; k < i; k++) begin
                            shift_reg[k] <= '0;
                        end
                    end else if (enable) begin
                        // First stage takes gated input data
                        shift_reg[0] <= effective_data_in[i];
                        
                        // Remaining stages shift data forward
                        for (int k = 1; k < i; k++) begin
                            shift_reg[k] <= shift_reg[k-1];
                        end
                    end
                end

                // Tap the output from the last stage of the shift chain
                assign dout[i] = shift_reg[i-1];
            end

        end
    endgenerate

endmodule