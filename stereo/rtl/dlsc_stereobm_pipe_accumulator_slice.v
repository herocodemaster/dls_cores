module dlsc_stereobm_pipe_accumulator_slice #(
    parameter IN_BITS       = 12,
    parameter OUT_BITS      = 16,
    parameter SAD           = 9
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // in
    input   wire [IN_BITS-1:0]      c0_sad,     // column SAD

    // out
    output  reg  [OUT_BITS-1:0]     c4_out_sad, // accumulated window SAD
    
    // control
    input   wire                    c1_valid,
    input   wire                    c1_en_sr,   // unmask shift-register output
    input   wire                    c2_first    // mask accumulator feedback
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam PAD = OUT_BITS - IN_BITS - 1;

`DLSC_KEEP_REG reg c2_valid;    // enable shift-register
`DLSC_KEEP_REG reg c3_valid;    // enable accumulator

always @(posedge clk) begin
    if(rst) begin
        c2_valid    <= 1'b0;
        c3_valid    <= 1'b0;
    end else begin
        c2_valid    <= c1_valid;
        c3_valid    <= c2_valid;
    end
end


// delay c0_sad to c2_sad
wire [IN_BITS-1:0] c2_sad;

dlsc_pipedelay #(
    .DATA       ( IN_BITS ),
    .DELAY      ( 2 )
) dlsc_pipedelay_inst_sad (
    .clk        ( clk ),
    .in_data    ( c0_sad ),
    .out_data   ( c2_sad )
);


// delay-line
wire [IN_BITS-1:0] c2_sad_d;
dlsc_pipedelay_clken #(
    .DATA   ( IN_BITS ),
    .DELAY  ( SAD )
) dlsc_pipedelay_clken_inst (
    .clk        ( clk ),
    .clk_en     ( c2_valid ),
    .in_data    ( c2_sad ),
    .out_data   ( c2_sad_d )
);


`DLSC_KEEP_REG reg c2_en_sr; // unmask shift-register output

always @(posedge clk) begin
    c2_en_sr    <= c1_en_sr;
end

reg [IN_BITS:0]     c3_sad;         // 1 extra bit for possible negative value

// subtract delayed SAD value
always @(posedge clk) begin
    c3_sad      <= {1'b0,c2_sad} - ( {1'b0,c2_sad_d} & {(IN_BITS+1){c2_en_sr}} );
end


`DLSC_KEEP_REG reg c3_first; // mask accumulator feedback

always @(posedge clk) begin
    c3_first    <= c2_first;
end

// accumulate SAD window
always @(posedge clk) begin
    if(c3_valid) begin
        // qualified, since we only want to accumulate valid values
        c4_out_sad  <= {{PAD{c3_sad[IN_BITS]}},c3_sad} + ( c4_out_sad & {OUT_BITS{!c3_first}} );
    end
end

endmodule

