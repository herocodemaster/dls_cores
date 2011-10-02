
module dlsc_axi_router_rd #(
    parameter ADDR              = 32,           // address bits
    parameter DATA              = 32,           // data bits
    parameter LEN               = 4,            // length bits
    parameter BUFFER            = 1,            // enable extra buffering
    parameter FAST_COMMAND      = 0,            // enable back-to-back commands
    parameter MOT               = 16,           // maximum outstanding transactions (not a hard limit)
    parameter LANES             = 1,            // number of internal data lanes
    parameter INPUTS            = 1,            // number of inputs (from masters)
    parameter OUTPUTS           = 1,            // number of outputs (to slaves)
    parameter [(OUTPUTS*ADDR)-1:0] MASKS = {(OUTPUTS*ADDR){1'b0}},  // output/slave address masks
    parameter [(OUTPUTS*ADDR)-1:0] BASES = {(OUTPUTS*ADDR){1'b0}}   // output/slave address bases
) (
    // System
    input   wire                            clk,
    input   wire                            rst,

    // ** AXI inputs ** (from masters)
    
    // Read command
    output  wire    [  INPUTS      -1:0]    in_ar_ready,
    input   wire    [  INPUTS      -1:0]    in_ar_valid,
    input   wire    [( INPUTS*ADDR)-1:0]    in_ar_addr,
    input   wire    [( INPUTS*LEN )-1:0]    in_ar_len,

    // Read data
    input   wire    [  INPUTS      -1:0]    in_r_ready,
    output  wire    [  INPUTS      -1:0]    in_r_valid,
    output  wire    [  INPUTS      -1:0]    in_r_last,
    output  wire    [( INPUTS*DATA)-1:0]    in_r_data,
    output  wire    [( INPUTS*2   )-1:0]    in_r_resp,

    // ** AXI outputs ** (to slaves)
    
    // Read command
    input   wire    [ OUTPUTS      -1:0]    out_ar_ready,
    output  wire    [ OUTPUTS      -1:0]    out_ar_valid,
    output  wire    [(OUTPUTS*ADDR)-1:0]    out_ar_addr,
    output  wire    [(OUTPUTS*LEN )-1:0]    out_ar_len,

    // Read data
    output  wire    [ OUTPUTS      -1:0]    out_r_ready,
    input   wire    [ OUTPUTS      -1:0]    out_r_valid,
    input   wire    [ OUTPUTS      -1:0]    out_r_last,
    input   wire    [(OUTPUTS*DATA)-1:0]    out_r_data,
    input   wire    [(OUTPUTS*2   )-1:0]    out_r_resp
);

genvar j;

// derived parameters

`include "dlsc_clog2.vh"

localparam INPUTSB  = (INPUTS >1) ? `dlsc_clog2(INPUTS ) : 1;
localparam OUTPUTSB = (OUTPUTS>1) ? `dlsc_clog2(OUTPUTS) : 1;
localparam LANESB   = (LANES  >1) ? `dlsc_clog2(LANES  ) : 1;

// command

wire    [INPUTS-1:0]    cmd_full_input;
wire    [OUTPUTS-1:0]   cmd_full_output;
wire                    cmd_push;
wire    [INPUTS-1:0]    cmd_input_onehot;
wire    [OUTPUTS-1:0]   cmd_output_onehot;
wire    [INPUTSB-1:0]   cmd_input;
wire    [OUTPUTSB-1:0]  cmd_output;

dlsc_axi_router_command #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .FAST_COMMAND   ( 0 ),
    .INPUTS         ( INPUTS ),
    .INPUTSB        ( INPUTSB ),
    .OUTPUTS        ( OUTPUTS ),
    .OUTPUTSB       ( OUTPUTSB ),
    .MASKS          ( MASKS ),
    .BASES          ( BASES )
) dlsc_axi_router_command_ar (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( in_ar_ready ),
    .in_valid       ( in_ar_valid ),
    .in_addr        ( in_ar_addr ),
    .in_len         ( in_ar_len ),
    .out_ready      ( out_ar_ready ),
    .out_valid      ( out_ar_valid ),
    .out_addr       ( out_ar_addr ),
    .out_len        ( out_ar_len ),
    .cmd_full_input ( cmd_full_input ),
    .cmd_full_output( cmd_full_output ),
    .cmd_push       ( cmd_push ),
    .cmd_input_onehot ( cmd_input_onehot ),
    .cmd_output_onehot ( cmd_output_onehot ),
    .cmd_input      ( cmd_input ),
    .cmd_output     ( cmd_output )
);

// data/response

wire [((DATA+2)*OUTPUTS)-1:0]   source_data;
wire [((DATA+2)*INPUTS )-1:0]   sink_data;

generate
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_SOURCES
    assign source_data[ j*(DATA+2) +: DATA+2 ] =
        { out_r_resp[ j*2 +: 2 ], out_r_data[ j*DATA +: DATA ] };
end
for(j=0;j<INPUTS;j=j+1) begin:GEN_SINKS
    assign { in_r_resp[ j*2 +: 2 ], in_r_data[ j*DATA +: DATA ] } =
        sink_data[ j*(DATA+2) +: DATA+2 ];
end
endgenerate

dlsc_axi_router_channel #(
    .DATA           ( DATA+2 ),
    .MOT            ( MOT ),
    .BUFFER         ( BUFFER ),
    .SOURCES        ( OUTPUTS ),
    .SOURCESB       ( OUTPUTSB ),
    .SINKS          ( INPUTS ),
    .SINKSB         ( INPUTSB ),
    .LANES          ( LANES ),
    .LANESB         ( LANESB )
) dlsc_axi_router_channel_r (
    .clk            ( clk ),
    .rst            ( rst ),
    .cmd_full_source( cmd_full_output ),
    .cmd_full_sink  ( cmd_full_input ),
    .cmd_push       ( cmd_push ),
    .cmd_source_onehot ( cmd_output_onehot ),
    .cmd_sink_onehot ( cmd_input_onehot ),
    .cmd_source     ( cmd_output ),
    .cmd_sink       ( cmd_input ),
    .source_ready   ( out_r_ready ),
    .source_valid   ( out_r_valid ),
    .source_last    ( out_r_last ),
    .source_data    ( source_data ),
    .sink_ready     ( in_r_ready ),
    .sink_valid     ( in_r_valid ),
    .sink_last      ( in_r_last ),
    .sink_data      ( sink_data )
);   

endmodule

