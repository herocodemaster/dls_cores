module dlsc_stereobm_multipipe #(
    parameter MULT_D        = 8,
    parameter MULT_R        = 1,
    parameter SAD           = 9,
    parameter DATA          = 9,    // width of input image data
    parameter SAD_BITS      = 16,   // width of SAD output data
    parameter PIPELINE_IN   = 0,
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter SAD_BITS_R    = (SAD_BITS*MULT_R),
    parameter SAD_BITS_RD   = (SAD_BITS_R*MULT_D)
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // from frontend row buffers
    input   wire                        in_right_valid,
    input   wire                        in_valid,
    input   wire                        in_first,
    input   wire    [(DATA*SAD_R)-1:0]  in_left,
    input   wire    [(DATA*SAD_R)-1:0]  in_right,

    // output to disparity comparator
    output  wire                        out_valid,
    output  wire    [SAD_BITS_RD-1:0]   out_sad
);

// wires for cascading pipe data
wire [(DATA*SAD_R)-1:0] cascade_right[MULT_D:0];
assign cascade_right[0] = in_right;

wire [MULT_D-1:0] out_valids;
assign out_valid = out_valids[0];

generate
    genvar j;
    genvar k;
    for(j=0;j<MULT_D;j=j+1) begin:GEN_PIPES

        wire [SAD_BITS_R-1:0] sad;

        for(k=0;k<MULT_R;k=k+1) begin:GEN_SAD
            assign out_sad[ (j*SAD_BITS)+(k*MULT_D*SAD_BITS) +: SAD_BITS ] = sad[ (k*SAD_BITS) +: SAD_BITS ];
        end

        dlsc_stereobm_pipe #(
            .MULT_R         ( MULT_R ),
            .SAD            ( SAD ),
            .DATA           ( DATA ),
            .SAD_BITS       ( SAD_BITS ),
            .PIPELINE_IN    ( PIPELINE_IN )
        ) dlsc_stereobm_pipe_inst (
            .clk            ( clk ),
            .rst            ( rst ),
            .in_right_valid ( in_right_valid ),
            .in_valid       ( in_valid ),
            .in_first       ( in_first ),
            .in_left        ( in_left ),
            .in_right       ( cascade_right[j] ),
            .cascade_right  ( cascade_right[j+1] ),
            .out_valid      ( out_valids[j] ),
            .out_sad        ( sad )
        );

    end
endgenerate


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
task report;
begin
    GEN_PIPES[0].dlsc_stereobm_pipe_inst.report;
end
endtask
`include "dlsc_sim_bot.vh"
`endif

endmodule

