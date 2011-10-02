
module dlsc_axi_router_channel_source #(
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
    output  wire                            cmd_full,
    input   wire                            cmd_push,
    input   wire    [SINKSB-1:0]            cmd_sink,

    // Source
    output  wire                            source_ready,
    input   wire                            source_valid,
    input   wire                            source_last,
    input   wire    [DATA-1:0]              source_data,

    // Sink status
    input   wire    [SINKS-1:0]             sink_source,

    // Lane arbitration
    output  wire                            arb_req,
    output  wire    [SINKSB-1:0]            arb_req_sink,
    input   wire                            arb_grant,
    input   wire    [LANESB-1:0]            arb_grant_lane,

    // Data to lanes
    input   wire    [LANES-1:0]             lane_in_ready,
    output  wire                            lane_in_valid,
    output  wire                            lane_in_last,
    output  wire    [DATA-1:0]              lane_in_data
);


// track sinks

wire                    arb_empty;

generate
if(SINKS > 1) begin:GEN_CMD_FIFO
    dlsc_fifo #(
        .DATA           ( SINKSB ),
        .DEPTH          ( MOT ),
        .ALMOST_FULL    ( 1 )
    ) dlsc_fifo_cmd (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( cmd_push ),
        .wr_data        ( cmd_sink ),
        .wr_full        (  ),
        .wr_almost_full ( cmd_full ),   // 1 less than full, since cmd_push has a 1 cycle pipeline delay
        .wr_free        (  ),
        .rd_pop         ( arb_grant ),
        .rd_data        ( arb_req_sink ),
        .rd_empty       ( arb_empty ),
        .rd_almost_empty(  ),
        .rd_count       (  )
    );
end else begin:GEN_CMD_CONST
    assign cmd_full     = 1'b0;
    assign arb_req_sink = 0;
    assign arb_empty    = 1'b0;
end
endgenerate


// buffer data

wire                    buf_ready;

generate
if(BUFFER>0) begin:GEN_BUFFER
    dlsc_fifo_rvh #(
        .DATA           ( DATA+1 ),
        .DEPTH          ( 16 ),
        .REGISTER       ( 0 )
    ) dlsc_fifo_data (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_ready       ( source_ready ),
        .wr_valid       ( source_valid ),
        .wr_data        ( { source_last, source_data } ),
        .wr_almost_full (  ),
        .rd_ready       ( buf_ready ),
        .rd_valid       ( lane_in_valid ),
        .rd_data        ( { lane_in_last, lane_in_data } ),
        .rd_almost_empty(  )
    );
end else begin:GEN_NO_BUFFER
    assign source_ready     = buf_ready;
    assign lane_in_valid    = source_valid;
    assign lane_in_last     = source_last;
    assign lane_in_data     = source_data;
end
endgenerate


// latch arbitration

reg                     grant;
reg     [LANESB-1:0]    lane;

assign                  buf_ready       = grant && lane_in_ready[lane];

wire                    grant_clear     = buf_ready && lane_in_valid && lane_in_last;

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
        lane    <= arb_grant_lane;
    end
end

// only request when we have data and aren't already transferring
assign                  arb_req         =   lane_in_valid &&                // must have at least 1 beat of data ready for next cycle
                                            (!grant || grant_clear) &&      // must be inactive (or about to be inactive)
                                            !arb_empty &&                   // arb_req_sink is only valid if FIFO isn't empty
                                            sink_source[arb_req_sink];      // destination sink must be ready for data from us

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

