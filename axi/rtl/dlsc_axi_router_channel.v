
module dlsc_axi_router_channel #(
    parameter DATA              = 32,
    parameter MOT               = 16,
    parameter BUFFER            = 0,
    parameter SOURCES           = 1,
    parameter SOURCESB          = 1,
    parameter SINKS             = 1,
    parameter SINKSB            = 1,
    parameter LANES             = 1,
    parameter LANESB            = 1
) (
    // System
    input   wire                            clk,
    input   wire                            rst,

    // Command
    output  wire    [ SOURCES       -1:0]   cmd_full_source,
    output  wire    [ SINKS         -1:0]   cmd_full_sink,
    input   wire                            cmd_push,
    input   wire    [ SOURCES       -1:0]   cmd_source_onehot,
    input   wire    [ SINKS         -1:0]   cmd_sink_onehot,
    input   wire    [ SOURCESB      -1:0]   cmd_source,
    input   wire    [ SINKSB        -1:0]   cmd_sink,

    // Sources
    output  wire    [ SOURCES       -1:0]   source_ready,
    input   wire    [ SOURCES       -1:0]   source_valid,
    input   wire    [ SOURCES       -1:0]   source_last,
    input   wire    [(SOURCES*DATA) -1:0]   source_data,

    // Sinks
    input   wire    [ SINKS         -1:0]   sink_ready,
    output  wire    [ SINKS         -1:0]   sink_valid,
    output  wire    [ SINKS         -1:0]   sink_last,
    output  wire    [(SINKS*DATA)   -1:0]   sink_data
);

genvar                  j;
genvar                  k;


// Arbiter

wire    [LANES-1:0]     lane_next_idle;
wire    [SOURCES-1:0]   arb_req;
wire    [(SOURCES*SINKSB)-1:0] arb_req_sink;
wire                    arb_grant;
wire    [SOURCES-1:0]   arb_grant_source_onehot;
wire    [SINKS-1:0]     arb_grant_sink_onehot;
wire    [LANES-1:0]     arb_grant_lane_onehot;
wire    [SOURCESB-1:0]  arb_grant_source;
wire    [SINKSB-1:0]    arb_grant_sink;
wire    [LANESB-1:0]    arb_grant_lane;

dlsc_axi_router_channel_arbiter #(
    .SOURCES        ( SOURCES ),
    .SOURCESB       ( SOURCESB ),
    .SINKS          ( SINKS ),
    .SINKSB         ( SINKSB ),
    .LANES          ( LANES ),
    .LANESB         ( LANESB )
) dlsc_axi_router_channel_arbiter_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .lane_next_idle ( lane_next_idle ),
    .arb_req        ( arb_req ),
    .arb_req_sink   ( arb_req_sink ),
    .arb_grant      ( arb_grant ),
    .arb_grant_source_onehot ( arb_grant_source_onehot ),
    .arb_grant_sink_onehot ( arb_grant_sink_onehot ),
    .arb_grant_lane_onehot ( arb_grant_lane_onehot ),
    .arb_grant_source ( arb_grant_source ),
    .arb_grant_sink ( arb_grant_sink ),
    .arb_grant_lane ( arb_grant_lane )
); 


// Sources

wire    [(SOURCES*SINKS)-1:0] sink_source_pre;

wire    [LANES-1:0]     lane_in_ready;
wire    [SOURCES-1:0]   lane_in_valid;
wire    [SOURCES-1:0]   lane_in_last;
wire    [(SOURCES*DATA)-1:0] lane_in_data;

generate
for(j=0;j<SOURCES;j=j+1) begin:GEN_SOURCES

    wire    [SINKS-1:0]     sink_source;

    for(k=0;k<SINKS;k=k+1) begin:GEN_SINK_SOURCE
        assign sink_source[k] = sink_source_pre[ j + (k*SOURCES) ];
    end

    dlsc_axi_router_channel_source #(
        .DATA           ( DATA ),
        .MOT            ( MOT ),
        .BUFFER         ( BUFFER ),
        .SOURCES        ( SOURCES ),
        .SOURCESB       ( SOURCESB ),
        .SINKS          ( SINKS ),
        .SINKSB         ( SINKSB ),
        .LANES          ( LANES ),
        .LANESB         ( LANESB )
    ) dlsc_axi_router_channel_source_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .cmd_full       ( cmd_full_source[j] ),
        .cmd_push       ( cmd_push && cmd_source_onehot[j] ),
        .cmd_sink       ( cmd_sink ),
        .source_ready   ( source_ready[j] ),
        .source_valid   ( source_valid[j] ),
        .source_last    ( source_last[j] ),
        .source_data    ( source_data[(j*DATA)+:DATA] ),
        .sink_source    ( sink_source ),
        .arb_req        ( arb_req[j] ),
        .arb_req_sink   ( arb_req_sink[(j*SINKSB)+:SINKSB] ),
        .arb_grant      ( arb_grant && arb_grant_source_onehot[j] ),
        .arb_grant_lane ( arb_grant_lane ),
        .lane_in_ready  ( lane_in_ready ),
        .lane_in_valid  ( lane_in_valid[j] ),
        .lane_in_last   ( lane_in_last[j] ),
        .lane_in_data   ( lane_in_data[(j*DATA)+:DATA] )
    );

end
endgenerate


// Sinks

wire    [SINKS-1:0]     lane_out_ready;
wire    [LANES-1:0]     lane_out_valid;
wire    [LANES-1:0]     lane_out_last;
wire    [(LANES*DATA)-1:0] lane_out_data;

generate
for(j=0;j<SINKS;j=j+1) begin:GEN_SINKS

    dlsc_axi_router_channel_sink #(
        .DATA           ( DATA ),
        .MOT            ( MOT ),
        .BUFFER         ( BUFFER ),
        .SOURCES        ( SOURCES ),
        .SOURCESB       ( SOURCESB ),
        .SINKS          ( SINKS ),
        .SINKSB         ( SINKSB ),
        .LANES          ( LANES ),
        .LANESB         ( LANESB )
    ) dlsc_axi_router_channel_sink_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .cmd_full       ( cmd_full_sink[j] ),
        .cmd_push       ( cmd_push && cmd_sink_onehot[j] ),
        .cmd_source     ( cmd_source ),
        .sink_ready     ( sink_ready[j] ),
        .sink_valid     ( sink_valid[j] ),
        .sink_last      ( sink_last[j] ),
        .sink_data      ( sink_data[(j*DATA)+:DATA] ),
        .sink_source    ( sink_source_pre[(j*SOURCES)+:SOURCES] ),
        .arb_grant      ( arb_grant && arb_grant_sink_onehot[j] ),
        .arb_grant_lane ( arb_grant_lane ),
        .lane_out_ready ( lane_out_ready[j] ),
        .lane_out_valid ( lane_out_valid ),
        .lane_out_last  ( lane_out_last ),
        .lane_out_data  ( lane_out_data )
    );

end
endgenerate


// Lanes

generate
for(j=0;j<LANES;j=j+1) begin:GEN_LANES

    dlsc_axi_router_channel_lane #(
        .DATA           ( DATA ),
        .SOURCES        ( SOURCES ),
        .SOURCESB       ( SOURCESB ),
        .SINKS          ( SINKS ),
        .SINKSB         ( SINKSB )
    ) dlsc_axi_router_channel_lane_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .lane_next_idle ( lane_next_idle[j] ),
        .arb_grant      ( arb_grant && arb_grant_lane_onehot[j] ),
        .arb_grant_source ( arb_grant_source ),
        .arb_grant_sink ( arb_grant_sink ),
        .lane_in_ready  ( lane_in_ready[j] ),
        .lane_in_valid  ( lane_in_valid ),
        .lane_in_last   ( lane_in_last ),
        .lane_in_data   ( lane_in_data ),
        .lane_out_ready ( lane_out_ready ),
        .lane_out_valid ( lane_out_valid[j] ),
        .lane_out_last  ( lane_out_last[j] ),
        .lane_out_data  ( lane_out_data[(j*DATA)+:DATA] )
    );

end
endgenerate


endmodule

