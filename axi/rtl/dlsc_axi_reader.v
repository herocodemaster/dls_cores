
module dlsc_axi_reader #(
    parameter ADDR          = 32,   // bits for AXI and command address fields
    parameter LEN           = 4,    // bits for AXI length field (DMA accesses will always be 2**LEN beats when aligned)
    parameter BLEN          = 12,   // bits for command byte-length field
    parameter MOT           = 16,   // maximum outstanding AXI transactions
    parameter FIFO_ADDR     = 8,    // downstream FIFO's ADDR parameter (>= LEN)
    parameter STROBE_EN     = 1,    // enable out_strb
    parameter WARNINGS      = 1     // enable warnings about output throttling
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Status/control
    input   wire                    axi_halt,       // prevent issuing new AXI transactions
    output  wire                    axi_busy,       // asserted whenever there are outstanding AXI transactions
    output  reg                     axi_error,      // asserts when an AXI bus error is encountered (can only be cleared through a reset)
    output  reg                     cmd_done,       // asserts for 1 cycle when the very last beat of data for a command is received

    // Command
    output  wire                    cmd_ready,
    input   wire                    cmd_valid,
    input   wire    [ADDR-1:0]      cmd_addr,
    input   wire    [BLEN-1:0]      cmd_bytes,

    // AXI read command
    input   wire                    axi_ar_ready,
    output  reg                     axi_ar_valid,
    output  reg     [ADDR-1:0]      axi_ar_addr,
    output  reg     [LEN-1:0]       axi_ar_len,

    // AXI read response
    output  wire                    axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [31:0]          axi_r_data,
    input   wire    [1:0]           axi_r_resp,

    // Data output (to FIFO)
    input   wire    [FIFO_ADDR:0]   out_free,       // number of free entries in FIFO
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_last,       // last beat for a command
    output  reg     [31:0]          out_data,
    output  reg     [3:0]           out_strb        // qualify 1st and last data beats (for unaligned accesses)
);

// create AXI commands

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

// track outstanding FIFO usage

wire [LEN+2:0]      cs_len_bytes_ceil   = (cs_len_bytes + {{(LEN+1){1'b0}},cs_addr[1:0]} + 3);      // round up to a word
wire [FIFO_ADDR:0]  cs_len_words        = { {(FIFO_ADDR-LEN){1'b0}} , cs_len_bytes_ceil[LEN+2:2] }; // get just word length
wire [FIFO_ADDR:0]  cs_len              = cs_len_words - 1;                                         // AXI word length (0 based)

reg  [FIFO_ADDR:0]  outstanding_len;
reg  [FIFO_ADDR:0]  next_outstanding_len;

wire [FIFO_ADDR:0]  free                = (out_free - outstanding_len); // out_free should never be less than outstanding_len
wire                free_okay           = |free[FIFO_ADDR:LEN];         // at least 2**LEN spaces are available

always @* begin
    next_outstanding_len = outstanding_len;

    if(cs_ready && cs_valid) begin
        next_outstanding_len = next_outstanding_len + cs_len_words;
    end
    if(out_ready && out_valid) begin
        next_outstanding_len = next_outstanding_len - 1;
    end
end

always @(posedge clk) begin
    if(rst) begin
        outstanding_len <= 0;
    end else begin
        outstanding_len <= next_outstanding_len;
    end
end

// save commands

wire            f_full;
wire            f_pop           = axi_r_ready && axi_r_valid && axi_r_last;

wire            f_last;

wire            f_empty;
assign          axi_busy        = !f_empty || out_valid;

dlsc_fifo #(
    .DEPTH          ( MOT ),
    .DATA           ( 1 )
) dlsc_fifo_last (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( cs_ready && cs_valid ),
    .wr_data        ( cs_last ),
    .wr_full        ( f_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( f_pop ),
    .rd_data        ( f_last ),
    .rd_empty       ( f_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);

// save strobes

wire            f_almost_full;

wire [1:0]      f_strb_start;
wire [1:0]      f_strb_end;

generate
if(STROBE_EN) begin:GEN_STROBE_FIFO

    wire [1:0]      cmd_strb_start  = cmd_addr[1:0];
    wire [1:0]      cmd_strb_end    = cmd_addr[1:0] + cmd_bytes[1:0];

    dlsc_fifo #(
        .DEPTH          ( MOT ),
        .DATA           ( 4 ),
        .ALMOST_FULL    ( 1 )
    ) dlsc_fifo_strb (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( cmd_ready && cmd_valid ),
        .wr_data        ( { cmd_strb_end, cmd_strb_start } ),
        .wr_full        (  ),
        .wr_almost_full ( f_almost_full ),
        .wr_free        (  ),
        .rd_pop         ( f_pop && f_last ),
        .rd_data        ( { f_strb_end, f_strb_start } ),
        .rd_empty       (  ),
        .rd_almost_empty(  ),
        .rd_count       (  )
    );

end else begin:GEN_NO_STROBE_FIFO
    assign          f_almost_full   = 1'b0;
    assign          f_strb_start    = 2'b00;
    assign          f_strb_end      = 2'b00;
end
endgenerate

// drive commands

assign          cs_ready        = !axi_ar_valid && !axi_halt && !axi_error && free_okay && !f_full && !f_almost_full;

always @(posedge clk) begin
    if(rst) begin
        axi_ar_valid    <= 1'b0;
    end else begin
        if(axi_ar_ready) begin
            axi_ar_valid    <= 1'b0;
        end
        if(cs_ready && cs_valid) begin
            axi_ar_valid    <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(cs_ready && cs_valid) begin
        axi_ar_addr     <= { cs_addr[ADDR-1:2], 2'b00 };
        axi_ar_len      <= cs_len[LEN-1:0];
    end
end

// drive done

always @(posedge clk) begin
    if(rst) begin
        cmd_done        <= 1'b0;
    end else begin
        cmd_done        <= out_ready && out_valid && out_last;
    end
end

// capture errors

wire            next_axi_error  = axi_error || (axi_r_valid && axi_r_resp != 2'b00);

always @(posedge clk) begin
    if(rst) begin
        axi_error       <= 1'b0;
    end else begin
        axi_error       <= next_axi_error;
    end
end

// drive output

assign          axi_r_ready     = (out_ready || !out_valid);

reg             next_valid;
reg             next_last;

always @* begin
    next_valid  = out_valid;
    next_last   = out_last;

    if(out_ready) begin
        next_valid  = 1'b0;
    end
    if(axi_r_ready && axi_r_valid) begin
        next_valid  = !next_axi_error;
        next_last   = axi_r_last && f_last;
    end
end

always @(posedge clk) begin
    if(rst) begin
        out_valid       <= 1'b0;
        out_last        <= 1'b1;
    end else begin
        out_valid       <= next_valid;
        out_last        <= next_last;
    end
end

reg  [3:0]      next_strb;

always @(posedge clk) begin
    if(axi_r_ready && axi_r_valid) begin
        out_data        <= axi_r_data;
        out_strb        <= next_strb;
    end
end

// compute strobe

always @* begin
    next_strb   = 4'hF;

    if(out_last) begin
        // first
        case(f_strb_start)
            2'b00: next_strb = 4'b1111;
            2'b01: next_strb = 4'b1110;
            2'b10: next_strb = 4'b1100;
            2'b11: next_strb = 4'b1000;
        endcase
    end
    if(next_last) begin
        // last
        case(f_strb_end)
            2'b01: next_strb = next_strb & 4'b0001;
            2'b10: next_strb = next_strb & 4'b0011;
            2'b11: next_strb = next_strb & 4'b0111;
            2'b00: next_strb = next_strb & 4'b1111;
        endcase
    end
end

// simulation sanity checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) if(!rst) begin

    if(out_free < outstanding_len) begin
        `dlsc_error("out_free should never be < outstanding_len");
    end

    if(WARNINGS && out_valid && !out_ready) begin
        `dlsc_warn("downstream FIFO is throttling (was out_free lying?)");
    end

end

`include "dlsc_sim_bot.vh"
`endif

endmodule

