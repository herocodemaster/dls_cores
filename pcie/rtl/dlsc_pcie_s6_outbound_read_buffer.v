
module dlsc_pcie_s6_outbound_read_buffer #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter TAG       = 5,
    parameter BUFA      = 9,
    parameter MOT       = 16
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // Read Command
    output  reg                 axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [ADDR-1:0]  axi_ar_addr,
    input   wire    [LEN-1:0]   axi_ar_len,

    // AXI read response
    input   wire                axi_r_ready,
    output  reg                 axi_r_valid,
    output  reg                 axi_r_last,
    output  reg     [31:0]      axi_r_data,
    output  reg     [1:0]       axi_r_resp,

    // Read command to _req
    input   wire                cmd_ar_ready,
    output  wire                cmd_ar_valid,
    output  wire    [ADDR-1:2]  cmd_ar_addr,
    output  wire    [LEN-1:0]   cmd_ar_len,

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
    output  reg                 dealloc_data,       // freed a dword

    // control/status
    output  reg                 rd_busy,
    input   wire                rd_disable,
    input   wire                rd_flush
);

`include "dlsc_synthesis.vh"

localparam  TAGS            = (2**TAG);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;


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

assign          cpl_ready       = alloc_valid ? 1'b0                : !rd_flush;
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
wire            ar_almost_full;
wire            ar_push         = axi_ar_ready && axi_ar_valid;
wire            ar_empty;
wire            ar_pop;

wire [LEN-1:0]  ar_len;

dlsc_fifo #(
    .DATA           ( LEN ),
    .DEPTH          ( MOT ),
    .ALMOST_FULL    ( 1 )
) dlsc_fifo_ar (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( ar_push ),
    .wr_data        ( axi_ar_len ),
    .wr_full        ( ar_full ),
    .wr_almost_full ( ar_almost_full ),
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


// Buffer commands to _req

wire            cmd_almost_full;

dlsc_fifo_rvho #(
    .DATA           ( ADDR -2 + LEN ),
    .DEPTH          ( 4 ),
    .ALMOST_FULL    ( 1 )
) dlsc_fifo_rvho_cmd (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( ar_push ),
    .wr_data        ( { axi_ar_addr[ADDR-1:2], axi_ar_len } ),
    .wr_full        (  ),
    .wr_almost_full ( cmd_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( cmd_ar_ready ),
    .rd_valid       ( cmd_ar_valid ),
    .rd_data        ( { cmd_ar_addr, cmd_ar_len } ),
    .rd_almost_empty(  )
);


// Create ar_ready

always @(posedge clk) begin
    if(rst) begin
        axi_ar_ready    <= 1'b0;
    end else begin
        axi_ar_ready    <= !cmd_almost_full && !ar_full && (!ar_almost_full || !axi_ar_valid) && !rd_disable;
    end
end


// Generate output

reg  [BUFA:0]   read_addr;

wire [BUFA:0]   read_count      = (read_addr_lim - read_addr);
wire            read_okay       = ((read_count > {{(BUFA+1-LEN){1'b0}},ar_len}) || rd_flush) && !ar_empty;

wire            buf_ready;
reg             buf_valid;
reg             buf_last;
reg             buf_flush;

assign          buf_rd_addr     = read_addr[BUFA-1:0];
assign          buf_rd_en       = (!buf_valid || buf_ready) && (!buf_last || read_okay);

assign          ar_pop          = buf_rd_en && r_last;
assign          r_inc           = buf_rd_en;

always @(posedge clk) begin
    if(rst) begin
        buf_valid       <= 1'b0;
        buf_last        <= 1'b1;
        buf_flush       <= 1'b0;
        dealloc_data    <= 1'b0;
        read_addr       <= 0;
    end else begin
        dealloc_data    <= 1'b0;
        if(buf_ready) begin
            buf_valid       <= 1'b0;
        end
        if(buf_rd_en) begin
            buf_valid       <= 1'b1;
            buf_last        <= r_last;
            buf_flush       <= rd_flush;
            dealloc_data    <= 1'b1;
            read_addr       <= read_addr + 1;
        end
    end
end


// Register output

assign          buf_ready       = (axi_r_ready || !axi_r_valid);

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid     <= 1'b0;
    end else begin
        if(axi_r_ready) begin
            axi_r_valid     <= 1'b0;
        end
        if(buf_ready && buf_valid) begin
            axi_r_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(buf_ready && buf_valid) begin
        axi_r_last      <= buf_last;
        if(buf_flush) begin
            axi_r_data      <= 32'd0;
            axi_r_resp      <= AXI_RESP_SLVERR;
        end else begin
            axi_r_data      <= buf_rd_data[31:0];
            axi_r_resp      <= buf_rd_data[33:32];
        end
    end
end


// Create busy flag

always @(posedge clk) begin
    if(rst) begin
        rd_busy         <= 1'b0;
    end else begin
        rd_busy         <= (axi_ar_ready && axi_ar_valid) || !ar_empty || buf_valid || (axi_r_valid && !axi_r_ready);
    end
end

endmodule

