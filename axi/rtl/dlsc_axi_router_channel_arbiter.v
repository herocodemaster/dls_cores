
module dlsc_axi_router_channel_arbiter #(
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

    // Lanes status
    input   wire    [LANES-1:0]             lane_next_idle,

    // Requests from sources
    input   wire    [SOURCES-1:0]           arb_req,
    input   wire    [(SOURCES*SINKSB)-1:0]  arb_req_sink,

    // Grants
    output  wire                            arb_grant,
    output  wire    [SOURCES-1:0]           arb_grant_source_onehot,
    output  wire    [SINKS-1:0]             arb_grant_sink_onehot,
    output  wire    [LANES-1:0]             arb_grant_lane_onehot,
    output  reg     [SOURCESB-1:0]          arb_grant_source,
    output  reg     [SINKSB-1:0]            arb_grant_sink,
    output  reg     [LANESB-1:0]            arb_grant_lane
);

integer                 i;
genvar                  j;

// do we have a lane to arbitrate for?
assign                  arb_grant       = |lane_next_idle && |arb_req;

// select highest priority source
dlsc_arbiter #(
    .CLIENTS        ( SOURCES )
) dlsc_arbiter_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .update         ( arb_grant ),
    .in             ( arb_req ),
    .out            ( arb_grant_source_onehot )
);

// encode winning source and select sink
always @* begin
    arb_grant_source    = {SOURCESB{1'bx}};
    arb_grant_sink      = {SINKSB{1'bx}};
    for(i=0;i<SOURCES;i=i+1) begin
        if(arb_grant_source_onehot[i]) begin
/* verilator lint_off WIDTH */
            arb_grant_source    = i;
/* verilator lint_on WIDTH */
            arb_grant_sink      = arb_req_sink[ (i*SINKSB) +: SINKSB ];
        end
    end
end

// create onehot
generate
    for(j=0;j<SINKS;j=j+1) begin:GEN_ASSIGN_SINKS
/* verilator lint_off WIDTH */
        assign arb_grant_sink_onehot[j] = (arb_grant_sink == j);
/* verilator lint_on WIDTH */
    end
endgenerate

// select lane
assign                  arb_grant_lane_onehot = lane_next_idle & ~(lane_next_idle - 1);

// encode lane
always @* begin
    arb_grant_lane      = {LANESB{1'bx}};
    for(i=0;i<LANES;i=i+1) begin
        if(arb_grant_lane_onehot[i]) begin
/* verilator lint_off WIDTH */
            arb_grant_lane      = i;
/* verilator lint_on WIDTH */
        end
    end
end

endmodule

