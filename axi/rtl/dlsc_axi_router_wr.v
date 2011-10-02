
module dlsc_axi_router_wr #(
    parameter ADDR              = 32,           // address bits
    parameter DATA              = 32,           // data bits
    parameter STRB              = (DATA/8),     // strobe bits (derived; don't touch)
    parameter LEN               = 4,            // length bits
    parameter BUFFER            = 1,            // enable extra buffering
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
    
    // Write command
    output  wire    [  INPUTS      -1:0]    in_aw_ready,
    input   wire    [  INPUTS      -1:0]    in_aw_valid,
    input   wire    [( INPUTS*ADDR)-1:0]    in_aw_addr,
    input   wire    [( INPUTS*LEN )-1:0]    in_aw_len,

    // Write data
    output  wire    [  INPUTS      -1:0]    in_w_ready,
    input   wire    [  INPUTS      -1:0]    in_w_valid,
    input   wire    [  INPUTS      -1:0]    in_w_last,
    input   wire    [( INPUTS*DATA)-1:0]    in_w_data,
    input   wire    [( INPUTS*STRB)-1:0]    in_w_strb,

    // Write response
    input   wire    [  INPUTS      -1:0]    in_b_ready,
    output  wire    [  INPUTS      -1:0]    in_b_valid,
    output  wire    [( INPUTS*2   )-1:0]    in_b_resp,

    // ** AXI outputs ** (to slaves)
    
    // Write command
    input   wire    [ OUTPUTS      -1:0]    out_aw_ready,
    output  wire    [ OUTPUTS      -1:0]    out_aw_valid,
    output  wire    [(OUTPUTS*ADDR)-1:0]    out_aw_addr,
    output  wire    [(OUTPUTS*LEN )-1:0]    out_aw_len,

    // Write data
    input   wire    [ OUTPUTS      -1:0]    out_w_ready,
    output  wire    [ OUTPUTS      -1:0]    out_w_valid,
    output  wire    [ OUTPUTS      -1:0]    out_w_last,
    output  wire    [(OUTPUTS*DATA)-1:0]    out_w_data,
    output  wire    [(OUTPUTS*STRB)-1:0]    out_w_strb,

    // Write response
    output  wire    [ OUTPUTS      -1:0]    out_b_ready,
    input   wire    [ OUTPUTS      -1:0]    out_b_valid,
    input   wire    [(OUTPUTS*2   )-1:0]    out_b_resp
);

genvar j;

// derived parameters

`include "dlsc_clog2.vh"

localparam INPUTSB  = (INPUTS >1) ? `dlsc_clog2(INPUTS ) : 1;
localparam OUTPUTSB = (OUTPUTS>1) ? `dlsc_clog2(OUTPUTS) : 1;
localparam LANESB   = (LANES  >1) ? `dlsc_clog2(LANES  ) : 1;

// command

wire                    cmd_full_w;
wire                    cmd_full_b;
wire                    cmd_push;
wire    [INPUTSB-1:0]   cmd_input;
wire    [OUTPUTSB-1:0]  cmd_output;

dlsc_axi_router_command #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .BUFFER         ( BUFFER ),
    .INPUTS         ( INPUTS ),
    .INPUTSB        ( INPUTSB ),
    .OUTPUTS        ( OUTPUTS ),
    .OUTPUTSB       ( OUTPUTSB ),
    .MASKS          ( MASKS ),
    .BASES          ( BASES )
) dlsc_axi_router_command_aw (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( in_aw_ready ),
    .in_valid       ( in_aw_valid ),
    .in_addr        ( in_aw_addr ),
    .in_len         ( in_aw_len ),
    .out_ready      ( out_aw_ready ),
    .out_valid      ( out_aw_valid ),
    .out_addr       ( out_aw_addr ),
    .out_len        ( out_aw_len ),
    .cmd_full       ( cmd_full_w || cmd_full_b ),
    .cmd_push       ( cmd_push ),
    .cmd_input      ( cmd_input ),
    .cmd_output     ( cmd_output )
);

// data

wire [((DATA+STRB)*INPUTS)-1:0]     source_data;
wire [((DATA+STRB)*OUTPUTS )-1:0]   sink_data;

generate
for(j=0;j<INPUTS;j=j+1) begin:GEN_SOURCES
    assign source_data[ j*(DATA+STRB) +: DATA+STRB ] =
        { in_w_strb[ j*STRB +: STRB ], in_w_data[ j*DATA +: DATA ] };
end
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_SINKS
    assign { out_w_strb[ j*STRB +: STRB ], out_w_data[ j*DATA +: DATA ] } =
        sink_data[ j*(DATA+STRB) +: DATA+STRB ];
end
endgenerate

dlsc_axi_router_channel #(
    .DATA           ( DATA+STRB ),
    .MOT            ( MOT ),
    .BUFFER         ( BUFFER ),
    .SOURCES        ( INPUTS ),
    .SOURCESB       ( INPUTSB ),
    .SINKS          ( OUTPUTS ),
    .SINKSB         ( OUTPUTSB ),
    .LANES          ( LANES ),
    .LANESB         ( LANESB )
) dlsc_axi_router_channel_w (
    .clk            ( clk ),
    .rst            ( rst ),
    .cmd_full       ( cmd_full_w ),
    .cmd_push       ( cmd_push ),
    .cmd_source     ( cmd_input ),
    .cmd_sink       ( cmd_output ),
    .source_ready   ( in_w_ready ),
    .source_valid   ( in_w_valid ),
    .source_last    ( in_w_last ),
    .source_data    ( source_data ),
    .sink_ready     ( out_w_ready ),
    .sink_valid     ( out_w_valid ),
    .sink_last      ( out_w_last ),
    .sink_data      ( sink_data )
);   

// response    

dlsc_axi_router_channel #(
    .DATA           ( 2 ),
    .MOT            ( MOT ),
    .BUFFER         ( BUFFER ),
    .SOURCES        ( OUTPUTS ),
    .SOURCESB       ( OUTPUTSB ),
    .SINKS          ( INPUTS ),
    .SINKSB         ( INPUTSB ),
    .LANES          ( 1 ),
    .LANESB         ( 1 )
) dlsc_axi_router_channel_b (
    .clk            ( clk ),
    .rst            ( rst ),
    .cmd_full       ( cmd_full_b ),
    .cmd_push       ( cmd_push ),
    .cmd_source     ( cmd_output ),
    .cmd_sink       ( cmd_input ),
    .source_ready   ( out_b_ready ),
    .source_valid   ( out_b_valid ),
    .source_last    ( {OUTPUTS{1'b1}} ),
    .source_data    ( out_b_resp ),
    .sink_ready     ( in_b_ready ),
    .sink_valid     ( in_b_valid ),
    .sink_last      (  ),
    .sink_data      ( in_b_resp )
);   

endmodule

