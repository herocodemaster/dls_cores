module dlsc_stereobm_pipe_accumulator #(
    parameter IN_BITS       = 12,
    parameter OUT_BITS      = 16,
    parameter SAD           = 9,
    parameter MULT_R        = 4,
    // derived parameters; don't touch
    parameter IN_BITS_R     = (IN_BITS*MULT_R),
    parameter OUT_BITS_R    = (OUT_BITS*MULT_R)
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    in_valid,
    input   wire                    in_first,
    input   wire [IN_BITS_R-1:0]    in_sad,

    output  reg                     out_valid,
    output  wire [OUT_BITS_R-1:0]   out_sad
);

`include "dlsc_clog2.vh"
localparam SAD_BITS = `dlsc_clog2(SAD);


// masking control logic
// shift-register output needs to be masked for SAD cycles
// output needs to be masked for SAD-1 cycles
// masking time is inclusive of in_first cycle

reg     [SAD_BITS-1:0]  cnt;
reg                     c1_en_sr;
reg                     c1_en_out;

always @(posedge clk) begin
    if(in_valid) begin
        if(in_first) begin
            cnt         <= 0;
            c1_en_sr    <= 1'b0;
            c1_en_out   <= 1'b0;
        end else if(!c1_en_sr) begin
            cnt         <= cnt + 1;
/* verilator lint_off WIDTH */
            if(cnt == (SAD-2)) c1_en_out <= 1'b1;
            if(cnt == (SAD-1)) c1_en_sr  <= 1'b1;
/* verilator lint_on WIDTH */
        end
    end
end


// delay in_first to c2_first
wire c2_first;
dlsc_pipedelay #(
    .DATA       ( 1 ),
    .DELAY      ( 2 )
) dlsc_pipedelay_inst_first (
    .clk        ( clk ),
    .in_data    ( in_first ),
    .out_data   ( c2_first )
);


reg c1_valid;
reg c2_out_valid;
reg c3_out_valid;

always @(posedge clk) begin
    if(rst) begin
        c1_valid        <= 1'b0;
        c2_out_valid    <= 1'b0;
        c3_out_valid    <= 1'b0;
        out_valid       <= 1'b0;
    end else begin
        c1_valid        <= in_valid;
        c2_out_valid    <= c1_valid && c1_en_out;
        c3_out_valid    <= c2_out_valid;
        out_valid       <= c3_out_valid;
    end
end


generate
    genvar j;
    for(j=0;j<MULT_R;j=j+1) begin:GEN_SLICES

        dlsc_stereobm_pipe_accumulator_slice #(
            .IN_BITS    ( IN_BITS ),
            .OUT_BITS   ( OUT_BITS ),
            .SAD        ( SAD )
        ) dlsc_stereobm_pipe_accumulator_slice_inst (
            .clk        ( clk ),
            .rst        ( rst ),
            .c0_sad     ( in_sad [ (j* IN_BITS) +:  IN_BITS ] ),
            .c4_out_sad ( out_sad[ (j*OUT_BITS) +: OUT_BITS ] ),
            .c1_valid   ( c1_valid ),
            .c1_en_sr   ( c1_en_sr ),
            .c2_first   ( c2_first )
        );

    end
endgenerate

//`ifdef DLSC_SIMULATION
//wire [IN_BITS-1:0] inputs [MULT_R-1:0];
//wire [OUT_BITS-1:0] outputs [MULT_R-1:0];
//
//generate
//    genvar g;
//    for(g=0;g<MULT_R;g=g+1) begin:GEN_DBG
//        assign inputs[g] = in_sad[(g*IN_BITS)+:IN_BITS];
//        assign outputs[g] = out_sad[(g*OUT_BITS)+:OUT_BITS];
//    end
//endgenerate
//`endif

endmodule

