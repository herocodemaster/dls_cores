
module dlsc_pcie_s6_outbound_read_buffer #(
    parameter LEN       = 4,
    parameter TAG       = 5,
    parameter BUFA      = 9,
    parameter MOT       = 16
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // AXI read command tracking
    output  wire                axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [LEN-1:0]   axi_ar_len,

    // AXI read response
    input   wire                axi_r_ready,
    output  reg                 axi_r_valid,
    output  reg                 axi_r_last,
    output  wire    [31:0]      axi_r_data,
    output  wire    [1:0]       axi_r_resp,

    // writes from completion handler
    output  wire                cpl_ready,
    input   wire                cpl_valid,
    input   wire                cpl_last,
    input   wire    [31:0]      cpl_data,
    input   wire    [1:0]       cpl_resp,
    input   wire    [TAG-1:0]   cpl_tag,
    
    // writes from allocator
    input   wire                alloc_init,
    input   wire                alloc_valid,
    input   wire    [TAG:0]     alloc_tag,
    input   wire    [BUFA:0]    alloc_bufa,

    // feedback to allocator
    output  reg                 dealloc_tag,        // freed a tag
    output  reg                 dealloc_data        // freed a dword
);

`include "dlsc_synthesis.vh"

localparam      TAGS            = (2**TAG);


// Read data buffer

wire            buf_wr_en;
wire [BUFA-1:0] buf_wr_addr;
wire [33:0]     buf_wr_data;
wire            buf_rd_en;
wire [BUFA-1:0] buf_rd_addr;
wire [33:0]     buf_rd_data;

dlsc_ram_dp #(
    .DATA           ( 34 ),
    .ADDR           ( BUFA ),
    .PIPELINE_WR    ( 0 ),
    .PIPELINE_RD    ( 1 )
) dlsc_ram_dp_r (
    .write_clk      ( clk ),
    .write_en       ( buf_wr_en ),
    .write_addr     ( buf_wr_addr ),
    .write_data     ( buf_wr_data ),
    .read_clk       ( clk ),
    .read_en        ( buf_rd_en ),
    .read_addr      ( buf_rd_addr ),
    .read_data      ( buf_rd_data )
);


// Dual-ported tag address memory

`DLSC_LUTRAM reg [BUFA+1:0] mem[TAGS-1:0];

wire [TAG-1:0]  mem_a_addr;
wire            mem_a_wr_en;
wire [BUFA+1:0] mem_a_wr_data;
wire [BUFA+1:0] mem_a_rd_data   = mem[mem_a_addr];
wire [TAG-1:0]  mem_b_addr;
wire [BUFA+1:0] mem_b_rd_data   = mem[mem_b_addr];

always @(posedge clk) begin
    if(mem_a_wr_en) begin
        mem[mem_a_addr] <= mem_a_wr_data;
    end
end


// Port A: allocations and completions

wire [BUFA:0]   cpl_addr        = mem_a_rd_data[BUFA:0];
wire [BUFA:0]   cpl_addr_inc    = cpl_addr + 1;

assign          cpl_ready       = alloc_valid ? 1'b0                : 1'b1;
assign          mem_a_addr      = alloc_valid ? alloc_tag[TAG-1:0]  : cpl_tag;
assign          mem_a_wr_en     = alloc_valid ? 1'b1                : cpl_valid;
assign          mem_a_wr_data   = alloc_valid ? {1'b0, alloc_bufa}  : {cpl_last, cpl_addr_inc};

assign          buf_wr_en       = cpl_ready && cpl_valid;
assign          buf_wr_addr     = cpl_addr[BUFA-1:0];
assign          buf_wr_data     = { cpl_resp, cpl_data };


// Port B: AXI read

reg  [TAG:0]    read_tag;
reg  [BUFA:0]   read_addr_lim;

assign          mem_b_addr      = read_tag[TAG-1:0];

wire [BUFA:0]   read_cpl_addr   = mem_b_rd_data[BUFA:0];
wire            read_cpl_done   = mem_b_rd_data[BUFA+1];

wire            read_tag_equ    = (read_tag == alloc_tag);

always @(posedge clk) begin
    if(rst) begin
        dealloc_tag     <= 1'b0;
        read_tag        <= 0;
        read_addr_lim   <= 0;
    end else begin
        dealloc_tag     <= 1'b0;
        if(!read_tag_equ) begin
            read_addr_lim   <= read_cpl_addr;
            if(read_cpl_done) begin
                dealloc_tag     <= 1'b1;
                read_tag        <= read_tag + 1;
            end
        end
    end
end


// Track read commands

wire            ar_full;
wire            ar_empty;
wire            ar_pop;

assign          axi_ar_ready    = !ar_full;

wire [LEN-1:0]  ar_len;

dlsc_fifo #(
    .DATA           ( LEN ),
    .DEPTH          ( MOT )
) dlsc_fifo_ar (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( axi_ar_ready && axi_ar_valid ),
    .wr_data        ( axi_ar_len ),
    .wr_full        ( ar_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( ar_pop ),
    .rd_data        ( ar_len ),
    .rd_empty       ( ar_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);

reg  [LEN-1:0]  r_cnt;
wire            r_last          = (ar_len == r_cnt);
wire            r_inc;

always @(posedge clk) begin
    if(ar_pop) begin
        r_cnt           <= 0;
    end else if(r_inc) begin
        r_cnt           <= r_cnt + 1;
    end
end


// Generate output

reg  [BUFA:0]   read_addr;

wire [BUFA:0]   read_count      = (read_addr_lim - read_addr);
wire            read_okay       = (read_count > {{(BUFA+1-LEN){1'b0}},ar_len}) && !ar_empty;

assign          buf_rd_addr     = read_addr[BUFA-1:0];
assign          buf_rd_en       = (!axi_r_valid || axi_r_ready) && (!axi_r_last || read_okay);

assign          ar_pop          = buf_rd_en && r_last;
assign          r_inc           = buf_rd_en;

assign { axi_r_resp, axi_r_data } = buf_rd_data;

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid     <= 1'b0;
        axi_r_last      <= 1'b1;
        dealloc_data    <= 1'b0;
        read_addr       <= 0;
    end else begin
        dealloc_data    <= 1'b0;
        if(axi_r_ready) begin
            axi_r_valid     <= 1'b0;
        end
        if(buf_rd_en) begin
            axi_r_valid     <= 1'b1;
            axi_r_last      <= r_last;
            dealloc_data    <= 1'b1;
            read_addr       <= read_addr + 1;
        end
    end
end


endmodule

