
module dlsc_pcie_s6_txfifo #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4     // depth of FIFO is 2**ADDR
) (
    // input
    input   wire                wr_clk,
    input   wire                wr_rst,
    output  wire                wr_ready,
    input   wire                wr_valid,
    input   wire                wr_last,
    input   wire    [DATA-1:0]  wr_data,

    // output
    input   wire                rd_clk,
    input   wire                rd_rst,
    input   wire                rd_ready,
    output  wire                rd_valid,
    output  wire                rd_last,
    output  wire    [DATA-1:0]  rd_data
);

wire            wr_push         = wr_ready && wr_valid;
wire            wr_full;
assign          wr_ready        = !wr_full;

wire            rd_pop          = rd_ready && rd_valid;
wire            rd_almost_empty;

dlsc_fifo_async #(
    .DATA           ( DATA + 1 ),
    .ADDR           ( ADDR ),
    .ALMOST_EMPTY   ( 2 )
) dlsc_fifo_async_inst (
    .wr_clk         ( wr_clk ),
    .wr_rst         ( wr_rst ),
    .wr_push        ( wr_push ),
    .wr_data        ( { wr_last, wr_data } ),
    .wr_full        ( wr_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_clk         ( rd_clk ),
    .rd_rst         ( rd_rst ),
    .rd_pop         ( rd_pop ),
    .rd_data        ( { rd_last, rd_data } ),
    .rd_empty       (  ),
    .rd_almost_empty( rd_almost_empty ),
    .rd_count       (  )
);

// hold off on driving first word of a TLP until we've accumulated 3 words..
// in order to prevent underruns when using streaming (cut-through)
// (can't set to more than 3, otherwise 3DW TLPs without data would not be sent)

reg             rd_first;

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_first    <= 1'b1;
    end else if(rd_ready && rd_valid) begin
        rd_first    <= rd_last;
    end
end

assign          rd_valid        = !rd_almost_empty || !rd_first;


endmodule
    
