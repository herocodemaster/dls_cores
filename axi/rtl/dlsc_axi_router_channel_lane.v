
module dlsc_axi_router_channel_lane #(
    parameter DATA              = 32,
    parameter SOURCES           = 1,
    parameter SOURCESB          = 1,
    parameter SINKS             = 1,
    parameter SINKSB            = 1
) (
    // System
    input   wire                            clk,
    input   wire                            rst,

    // Lane status
    output  wire                            lane_next_idle,

    // Lane arbitration
    input   wire                            arb_grant,
    input   wire    [SOURCESB-1:0]          arb_grant_source,
    input   wire    [SINKSB-1:0]            arb_grant_sink,

    // Data from sources
    output  wire                            lane_in_ready,
    input   wire    [SOURCES-1:0]           lane_in_valid,
    input   wire    [SOURCES-1:0]           lane_in_last,
    input   wire    [(SOURCES*DATA)-1:0]    lane_in_data,

    // Data to sinks
    input   wire    [SINKS-1:0]             lane_out_ready,
    output  wire                            lane_out_valid,
    output  wire                            lane_out_last,
    output  wire    [DATA-1:0]              lane_out_data
);

genvar j;

wire    [DATA-1:0]      lane_in_data_mux[SOURCES-1:0];
generate
for(j=0;j<SOURCES;j=j+1) begin:GEN_LANE_IN_DATA_MUX
    assign lane_in_data_mux[j] = lane_in_data[(j*DATA)+:DATA];
end
endgenerate;


// latch arbitration

reg                     grant;
reg     [SOURCESB-1:0]  source;
reg     [SINKSB-1:0]    sink;

assign                  lane_in_ready   = lane_out_ready[sink];
assign                  lane_out_valid  = lane_in_valid[source];
assign                  lane_out_last   = lane_in_last[source];
assign                  lane_out_data   = lane_in_data_mux[source];

wire                    grant_clear     = lane_in_ready && lane_out_valid && lane_out_last;

assign                  lane_next_idle  = !grant || grant_clear;

always @(posedge clk) begin
    if(rst) begin
        grant   <= 1'b0;
    end else begin
        if(grant_clear) begin
            // clear arbitration on last beat
            grant   <= 1'b0;
        end
        if(arb_grant) begin
            // latch arbitration on grant
            grant   <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(arb_grant) begin
        source  <= arb_grant_source;
        sink    <= arb_grant_sink;
    end
end


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(arb_grant && grant && !grant_clear) begin
        `dlsc_error("grant overflow");
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

