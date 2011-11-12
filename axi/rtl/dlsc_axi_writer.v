
module dlsc_axi_writer #(
    parameter ADDR          = 32,   // bits for AXI and command address fields
    parameter LEN           = 4,    // bits for AXI length field (DMA accesses will always be 2**LEN beats when aligned)
    parameter BLEN          = 12,   // bits for command byte-length field
    parameter MOT           = 16,   // maximum outstanding AXI transactions
    parameter FIFO_ADDR     = 8,    // upstream FIFO's ADDR parameter (>= LEN)
    parameter WARNINGS      = 1     // enable warnings about input throttling
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Status/control
    input   wire                    axi_halt,       // prevent issuing new AXI transactions
    output  wire                    axi_busy,       // asserted whenever there are outstanding AXI transactions
    output  reg                     axi_error,      // asserts when an AXI bus error is encountered (can only be cleared through a reset)
    output  reg                     cmd_done,       // asserts for 1 cycle when the very last beat of data for a command is written and acknowledged

    // Command
    output  wire                    cmd_ready,
    input   wire                    cmd_valid,
    input   wire    [ADDR-1:0]      cmd_addr,
    input   wire    [BLEN-1:0]      cmd_bytes,

    // AXI write command
    input   wire                    axi_aw_ready,
    output  reg                     axi_aw_valid,
    output  reg     [ADDR-1:0]      axi_aw_addr,
    output  reg     [LEN-1:0]       axi_aw_len,

    // AXI write data
    input   wire                    axi_w_ready,
    output  wire                    axi_w_valid,
    output  wire                    axi_w_last,
    output  wire    [31:0]          axi_w_data,
    output  wire    [3:0]           axi_w_strb,

    // AXI write response
    output  wire                    axi_b_ready,
    input   wire                    axi_b_valid,
    input   wire    [1:0]           axi_b_resp,

    // Data input (from FIFO)
    input   wire    [FIFO_ADDR:0]   in_count,       // number of valid entries in FIFO
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [31:0]          in_data,
    input   wire    [3:0]           in_strb
);

// create commands

wire            cs_ready;
wire            cs_valid;
wire [ADDR-1:0] cs_addr;
wire [LEN+2:0]  cs_len_bytes;
wire            cs_last;

dlsc_dma_cmdsplit #(
    .ADDR           ( ADDR ),
    .ILEN           ( BLEN ),
    .OLEN           ( LEN+2 )
) dlsc_dma_cmdsplit_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( cmd_ready ),
    .in_valid       ( cmd_valid ),
    .in_addr        ( cmd_addr ),
    .in_len         ( cmd_bytes ),
    .out_ready      ( cs_ready ),
    .out_valid      ( cs_valid ),
    .out_addr       ( cs_addr ),
    .out_len        ( cs_len_bytes ),
    .out_last       ( cs_last )
);

wire [LEN+2:0]      cs_len_bytes_ceil   = (cs_len_bytes + {{(LEN+1){1'b0}},cs_addr[1:0]} + 3);      // round up to a word
wire [FIFO_ADDR:0]  cs_len_words        = { {(FIFO_ADDR-LEN){1'b0}} , cs_len_bytes_ceil[LEN+2:2] }; // get just word length

// register commands before issuing

wire                c_ready;
reg                 c_valid;
reg                 c_last;
reg  [ADDR-1:0]     c_addr;
reg  [FIFO_ADDR:0]  c_len_words;
wire [FIFO_ADDR:0]  c_len               = c_len_words - 1;                                          // AXI word length (0 based)

assign              cs_ready            = !c_valid;

always @(posedge clk) begin
    if(rst) begin
        c_valid     <= 1'b0;
    end else begin
        if(c_ready             ) c_valid <= 1'b0;
        if(cs_ready && cs_valid) c_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(cs_ready && cs_valid) begin
        c_last      <= cs_last;
        c_addr      <= cs_addr;
        c_len_words <= cs_len_words;
    end
end

// drive commands

always @(posedge clk) begin
    if(rst) begin
        axi_aw_valid    <= 1'b0;
    end else begin
        if(axi_aw_ready      ) axi_aw_valid <= 1'b0;
        if(c_ready && c_valid) axi_aw_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(c_ready && c_valid) begin
        axi_aw_addr <= { c_addr[ADDR-1:2], 2'b00 };
        axi_aw_len  <= c_len[LEN-1:0];
    end
end

// drive data

wire            d_ready;
reg             d_valid;
reg  [LEN-1:0]  d_len;
reg             d_last;

assign          in_ready        = d_valid && (axi_w_ready || !axi_w_valid);

assign          d_ready         = in_ready && in_valid && d_last;

always @(posedge clk) begin
    if(rst) begin
        d_valid     <= 1'b0;
    end else begin
        if(d_ready           ) d_valid <= 1'b0;
        if(c_ready && c_valid) d_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(in_ready && in_valid && !d_last) begin
        d_len       <= d_len - 1;
        d_last      <= (d_len == 1);
    end
    if(c_ready && c_valid) begin
        d_len       <= c_len[LEN-1:0];
        d_last      <= (c_len == 0);
    end
end

always @(posedge clk) begin
    if(rst) begin
        axi_w_valid <= 1'b0;
    end else begin
        if(axi_w_ready         ) axi_w_valid <= 1'b0;
        if(in_ready && in_valid) axi_w_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(in_ready && in_valid) begin
        axi_w_data  <= in_data;
        axi_w_strb  <= in_strb;
        axi_w_last  <= d_last;
    end
end

// track last

wire            f_full;
wire            f_pop           = axi_b_ready && axi_b_valid;

wire            f_last;

wire            f_empty;
assign          axi_b_ready     = !f_empty;
assign          axi_busy        = !f_empty;

dlsc_fifo #(
    .DEPTH          ( MOT ),
    .DATA           ( 1 )
) dlsc_fifo_last (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( c_ready && c_valid ),
    .wr_data        ( c_last ),
    .wr_full        ( f_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( f_pop ),
    .rd_data        ( f_last ),
    .rd_empty       ( f_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);

// capture errors

wire            next_axi_error  = axi_error || (axi_b_valid && axi_b_resp != 2'b00);

always @(posedge clk) begin
    if(rst) begin
        axi_error       <= 1'b0;
    end else begin
        axi_error       <= next_axi_error;
    end
end

// handshake commands

wire            count_okay      = ( in_count >= (c_len_words + {{FIFO_ADDR{1'b0}},d_valid}) ); // need 1 extra word if in_count includes a value that is being popped as part of the previous command

assign          c_ready         = !axi_aw_valid && !axi_halt && !axi_error && count_okay && !f_full && (d_ready || !d_valid);

// drive done

always @(posedge clk) begin
    if(rst) begin
        cmd_done    <= 1'b0;
    end else begin
        cmd_done    <= axi_b_ready && axi_b_valid && f_last;
    end
end

// simulation sanity checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) if(!rst) begin

    if(WARNINGS && in_ready && !in_valid) begin
        `dlsc_warn("upstream FIFO is throttling (was in_count lying?)");
    end

end

`include "dlsc_sim_bot.vh"
`endif

endmodule

