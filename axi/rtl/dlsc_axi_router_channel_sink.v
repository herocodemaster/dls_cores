
module dlsc_axi_router_channel_sink #(
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
    input   wire    [SOURCESB-1:0]          cmd_source,

    // Sink
    input   wire                            sink_ready,
    output  wire                            sink_valid,
    output  wire                            sink_last,
    output  wire    [DATA-1:0]              sink_data,

    // Sink status
    output  wire    [SOURCES-1:0]           sink_source,

    // Lane arbitration
    input   wire                            arb_grant,
    input   wire    [LANESB-1:0]            arb_grant_lane,

    // Data from lanes
    output  wire                            lane_out_ready,
    input   wire    [LANES-1:0]             lane_out_valid,
    input   wire    [LANES-1:0]             lane_out_last,
    input   wire    [(LANES*DATA)-1:0]      lane_out_data
);

integer                 i;


// track sources

wire                    arb_empty;
wire    [SOURCESB-1:0]  arb_source;

generate
if(SOURCES > 1) begin:GEN_CMD_FIFO
    dlsc_fifo #(
        .DATA           ( SOURCESB ),
        .DEPTH          ( MOT ),
        .ALMOST_FULL    ( 1 )
    ) dlsc_fifo_cmd (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( cmd_push ),
        .wr_data        ( cmd_source ),
        .wr_full        (  ),
        .wr_almost_full ( cmd_full ),   // 1 less than full, since cmd_push has a 1 cycle pipeline delay
        .wr_free        (  ),
        .rd_pop         ( arb_grant ),
        .rd_data        ( arb_source ),
        .rd_empty       ( arb_empty ),
        .rd_almost_empty(  ),
        .rd_count       (  )
    );
end else begin:GEN_CMD_CONST
    assign cmd_full     = 1'b0;
    assign arb_source   = 0;
    assign arb_empty    = 1'b0;
end
endgenerate


// buffer data

wire                    buf_valid;
wire                    buf_last;
wire    [DATA-1:0]      buf_data;
wire                    buf_almost_full;

generate
if(BUFFER>0) begin:GEN_BUFFER
    dlsc_fifo_rvh #(
        .DATA           ( DATA+1 ),
        .DEPTH          ( 16 ),
        .ALMOST_FULL    ( 12 ),
        .REGISTER       ( 1 )
    ) dlsc_fifo_data (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_ready       ( lane_out_ready ),
        .wr_valid       ( buf_valid ),
        .wr_data        ( { buf_last, buf_data } ),
        .wr_almost_full ( buf_almost_full ),
        .rd_ready       ( sink_ready ),
        .rd_valid       ( sink_valid ),
        .rd_data        ( { sink_last, sink_data } ),
        .rd_almost_empty(  )
    );
end else begin:GEN_NO_BUFFER
    assign buf_almost_full  = 1'b0;
    assign lane_out_ready   = sink_ready;
    assign sink_valid       = buf_valid;
    assign sink_last        = buf_last;
    assign sink_data        = buf_data;
end
endgenerate


// latch arbitration

reg                     grant;
reg     [LANESB-1:0]    lane;

assign                  buf_valid       = grant && lane_out_valid[lane];

wire                    grant_clear     = lane_out_ready && buf_valid && buf_last;

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


// generate status

genvar j;
generate
    for(j=0;j<SOURCES;j=j+1) begin:GEN_STATUS
/* verilator lint_off WIDTH */
        assign sink_source[j] = !buf_almost_full && !arb_empty && (arb_source == j) && (!grant || grant_clear);
/* verilator lint_on WIDTH */
    end
endgenerate


// mux data

wire    [DATA-1:0]      lane_out_data_mux[LANES-1:0];
generate
for(j=0;j<LANES;j=j+1) begin:GEN_LANE_OUT_DATA_MUX
    assign lane_out_data_mux[j] = lane_out_data[(j*DATA)+:DATA];
end
endgenerate

assign                  buf_last        = lane_out_last[lane];
assign                  buf_data        = lane_out_data_mux[lane];


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

