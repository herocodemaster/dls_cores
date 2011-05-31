module dlsc_stereobm_pipe_adder #(
    parameter DATA          = 16,
    parameter SUM_BITS      = DATA+4,
    parameter SAD           = 15,
    parameter MULT_R        = 3,
    parameter META          = 4,
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter SUM_BITS_R    = (SUM_BITS*MULT_R)
) (
    input   wire                            clk,
    input   wire                            rst,
    
    input   wire                            in_valid,
    input   wire    [META-1:0]              in_meta,
    input   wire    [(DATA*SAD_R)-1:0]      in_data,
    
    output  wire                            out_valid,
    output  wire    [META-1:0]              out_meta,
    output  wire    [SUM_BITS_R-1:0]        out_data
);

/* verilator tracing_off */

genvar j;

`include "dlsc_clog2.vh"

localparam LAT0 = `dlsc_clog2(SAD);     // latency through first stage
localparam LATN = LAT0 + MULT_R - 1;    // latency through last stage

// delay valid/meta
dlsc_pipedelay_valid #(
    .DATA       ( META ),
    .DELAY      ( LATN )
) dlsc_pipedelay_valid_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( in_valid ),
    .in_data    ( in_meta ),
    .out_valid  ( out_valid ),
    .out_data   ( out_meta )
);

// outputs from each SAD stage
wire [SUM_BITS_R-1:0] sad;

// first SAD
dlsc_adder_tree #(
    .IN_BITS    ( DATA ),
    .OUT_BITS   ( SUM_BITS ),
    .INPUTS     ( SAD ),
    .META       ( 1 )
) dlsc_adder_tree_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( 1'b1 ),
    .in_meta    ( 1'b0 ),
    .in_data    ( in_data[ 0 +: (DATA*SAD) ] ),
    .out_valid  (  ),
    .out_meta   (  ),
    .out_data   ( sad[ 0 +: SUM_BITS ] )
);

generate

    // generate other SADs
    for(j=0;j<(MULT_R-1);j=j+1) begin:GEN_SADS
        dlsc_stereobm_pipe_adder_slice #(
            .DATA       ( DATA ),
            .SUM_BITS   ( SUM_BITS ),
            .DELAY      ( LAT0+j )
        ) dlsc_stereobm_pipe_adder_slice_inst (
            .clk        ( clk ),
            .in_sub     ( in_data[ ((j+  0)*DATA) +: DATA ] ),      // subtract value falling outside window
            .in_add     ( in_data[ ((j+SAD)*DATA) +: DATA ] ),      // add value now within window
            .in_data    ( sad[ ((j+0)*SUM_BITS) +: SUM_BITS ] ),    // previous window
            .out_data   ( sad[ ((j+1)*SUM_BITS) +: SUM_BITS ] )     // resultant window (previous+add-sub)
        );
    end

    // generate delays for each output
    for(j=0;j<MULT_R;j=j+1) begin:GEN_DELAYS
        dlsc_pipedelay #(
            .DATA       ( SUM_BITS ),
            .DELAY      ( (MULT_R-1)-j )
        ) dlsc_pipedelay_valid_inst (
            .clk        ( clk ),
            .in_data    ( sad     [ (j*SUM_BITS) +: SUM_BITS ] ),
            .out_data   ( out_data[ (j*SUM_BITS) +: SUM_BITS ] )
        );
    end

endgenerate

/* verilator tracing_on */


//`ifdef DLSC_SIMULATION
//
//wire [DATA-1:0] inputs [SAD+MULT_R-2:0];
//wire [SUM_BITS-1:0] outputs [MULT_R-1:0];
//
//generate
//genvar g;
//for(g=0;g<SAD_R;g=g+1) begin:GEN_DBG_INPUTS
//    assign inputs[g] = in_data[(g*DATA)+DATA-1:(g*DATA)];
//end
//for(g=0;g<MULT_R;g=g+1) begin:GEN_DBG_OUTPUTS
//    assign outputs[g] = out_data[(g*SUM_BITS)+SUM_BITS-1:(g*SUM_BITS)];
//end
//endgenerate
//
//`endif


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
task report;
begin
//    dlsc_adder_tree_inst_com.report;
end
endtask
`include "dlsc_sim_bot.vh"
`endif


endmodule

