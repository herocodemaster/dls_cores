
module dlsc_pcie_s6_inbound_read #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter BUFA      = 8,            // must be >= 6 (64 words; 256 bytes.. twice the RCB)
    parameter MOT       = 16,
    parameter TOKN      = 4
) (
    // System
    input   wire                clk,
    input   wire                rst,

    // Status
    output  wire                rx_np_ok,
    
    // Config
    input   wire    [2:0]       max_payload_size,

    // Transaction ordering token interlock
    output  reg     [TOKN-1:0]  token_oldest,
    input   wire    [TOKN-1:0]  token_wr,

    // Request header from dispatcher
    output  wire                req_h_ready,
    input   wire                req_h_valid,
    input   wire                req_h_mem,
    input   wire    [ADDR-1:2]  req_h_addr,
    input   wire    [9:0]       req_h_len,
    input   wire    [3:0]       req_h_be_first,
    input   wire    [3:0]       req_h_be_last,
    input   wire    [TOKN-1:0]  req_h_token,

    // Header to completer
    input   wire                cpl_h_ready,
    output  wire                cpl_h_valid,
    output  wire    [6:0]       cpl_h_addr,
    output  wire    [9:0]       cpl_h_len,
    output  wire    [11:0]      cpl_h_bytes,
    output  wire                cpl_h_last,
    output  wire    [1:0]       cpl_h_resp,

    // Data to completer
    input   wire                cpl_d_ready,
    output  wire                cpl_d_valid,
    output  wire    [31:0]      cpl_d_data,
    output  wire                cpl_d_last,
    
    // AXI read command
    input   wire                axi_ar_ready,
    output  reg                 axi_ar_valid,
    output  reg     [ADDR-1:0]  axi_ar_addr,
    output  reg     [LEN-1:0]   axi_ar_len,

    // AXI read response
    output  reg                 axi_r_ready,
    input   wire                axi_r_valid,
    input   wire                axi_r_last,
    input   wire    [31:0]      axi_r_data,
    input   wire    [1:0]       axi_r_resp,

    // control/status
    output  reg                 rd_busy,
    input   wire                rd_disable,
    input   wire                rd_flush
);

`include "dlsc_clog2.vh"

localparam  AXI_RESP_OKAY       = 2'b00,
            AXI_RESP_SLVERR     = 2'b10,
            AXI_RESP_DECERR     = 2'b11;

// limit AR requests to 1/4th of the buffer size
localparam  AR_MAX_SIZE_DW      = ((2**LEN) > ((2**BUFA)/4)) ? ((2**BUFA)/4) : (2**LEN);

// limit response TLPs to half the buffer size
localparam  RCB_MAX_SIZE_DW     = (2**BUFA)/2;


// Buffer request TLPs for AXI

wire            axi_h_in_full;
wire            rcb_h_in_full;

assign          req_h_ready     = !axi_h_in_full && !rcb_h_in_full;

wire            req_h_push      = req_h_ready && req_h_valid;

wire            axi_h_ready;
wire            axi_h_valid;
wire [ADDR-1:2] axi_h_addr;
wire [9:0]      axi_h_len;
wire [TOKN-1:0] axi_h_token;

dlsc_fifo_rvho #(
    .DATA           ( ADDR-2+10+TOKN ),
    .DEPTH          ( 16 )
) dlsc_fifo_rvho_axih (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( req_h_push ),
    .wr_data        ( {
        req_h_addr,
        req_h_len,
        req_h_token } ),
    .wr_full        ( axi_h_in_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_ready       ( axi_h_ready ),
    .rd_valid       ( axi_h_valid ),
    .rd_data        ( {
        axi_h_addr,
        axi_h_len,
        axi_h_token } ),
    .rd_almost_empty(  )
);


// Buffer request TLPs for RCB

wire            rcb_h_ready;
wire            rcb_h_valid;
wire [11:2]     rcb_h_addr;
wire [9:0]      rcb_h_len;
wire [3:0]      rcb_h_be_first;
wire [3:0]      rcb_h_be_last;
wire            rcb_h_mem;

wire            rcb_h_almost_full;
assign          rx_np_ok        = !rcb_h_almost_full;

dlsc_fifo_rvho #(
    .DATA           ( 10+10+8+1 ),
    .DEPTH          ( 16 ),
    .ALMOST_FULL    ( 4 )
) dlsc_fifo_rvho_rcbh (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( req_h_push ),
    .wr_data        ( {
        req_h_addr[11:2],
        req_h_len,
        req_h_be_first,
        req_h_be_last,
        req_h_mem } ),
    .wr_full        ( rcb_h_in_full ),
    .wr_almost_full ( rcb_h_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( rcb_h_ready ),
    .rd_valid       ( rcb_h_valid ),
    .rd_data        ( {
        rcb_h_addr,
        rcb_h_len,
        rcb_h_be_first,
        rcb_h_be_last,
        rcb_h_mem } ),
    .rd_almost_empty(  )
);


// Create AXI commands

wire            cmd_ready;
wire            cmd_valid;
wire [ADDR-1:2] cmd_addr;
wire [LEN:0]    cmd_len;
wire            cmd_last;
wire [TOKN-1:0] cmd_token;

dlsc_pcie_s6_cmdsplit #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN+1 ),
    .OUT_SUB        ( 0 ),
    .MAX_SIZE       ( AR_MAX_SIZE_DW*4 ),
    .ALIGN          ( 0 ),
    .META           ( TOKN ),
    .REGISTER       ( 0 )
) dlsc_pcie_s6_cmdsplit_cmd (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( axi_h_ready ),
    .in_valid       ( axi_h_valid ),
    .in_addr        ( axi_h_addr ),
    .in_len         ( axi_h_len ),
    .in_meta        ( axi_h_token ),
    .max_size       ( max_payload_size ),   // limit AXI commands to max payload (only really a concern for large LEN)
    .out_ready      ( cmd_ready ),
    .out_valid      ( cmd_valid ),
    .out_addr       ( cmd_addr ),
    .out_len        ( cmd_len ),
    .out_meta       ( cmd_token ),
    .out_last       ( cmd_last )
);

always @(posedge clk) begin
    if(rst) begin
        axi_ar_valid    <= 1'b0;
    end else begin
        if(axi_ar_ready) begin
            axi_ar_valid    <= 1'b0;
        end
        if(cmd_ready && cmd_valid) begin
            axi_ar_valid    <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(cmd_ready && cmd_valid) begin
        axi_ar_addr     <= { cmd_addr, 2'b00 };
        axi_ar_len      <= cmd_len[LEN-1:0] - 1;
    end
end


// Create response headers

wire            rcb_ready;
wire            rcb_valid;

wire [6:0]      rcb_addr;
wire [9:0]      rcb_len;
wire [11:0]     rcb_bytes;
wire            rcb_last;

dlsc_pcie_s6_inbound_read_rcb #(
    .MAX_SIZE       ( RCB_MAX_SIZE_DW*4 ),
    .REGISTER       ( 0 )
) dlsc_pcie_s6_inbound_read_rcb_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .tlp_h_ready    ( rcb_h_ready ),
    .tlp_h_valid    ( rcb_h_valid ),
    .tlp_h_mem      ( rcb_h_mem ),
    .tlp_h_addr     ( rcb_h_addr ),
    .tlp_h_len      ( rcb_h_len ),
    .tlp_h_be_first ( rcb_h_be_first ),
    .tlp_h_be_last  ( rcb_h_be_last ),
    .rcb_ready      ( rcb_ready ),
    .rcb_valid      ( rcb_valid ),
    .rcb_addr       ( rcb_addr ),
    .rcb_len        ( rcb_len ),
    .rcb_bytes      ( rcb_bytes ),
    .rcb_last       ( rcb_last ),
    .max_payload_size ( max_payload_size )
);


// Register response headers and create axi_r_ready

reg  [6:0]      r_addr;
reg  [9:0]      r_len;
reg  [11:0]     r_bytes;
reg             r_last;

wire            resp_almost_full;
wire            r_len_last;

assign          rcb_ready       = (!axi_r_ready || (axi_r_valid && r_len_last)) && (!resp_almost_full || rd_flush);

always @(posedge clk) begin
    if(rst) begin
        axi_r_ready     <= 1'b0;
    end else begin
        if(axi_r_valid && r_len_last) begin
            axi_r_ready     <= 1'b0;
        end
        if(rcb_ready && rcb_valid) begin
            axi_r_ready     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rcb_ready && rcb_valid) begin
        r_addr      <= rcb_addr;
        r_len       <= rcb_len;
        r_bytes     <= rcb_bytes;
        r_last      <= rcb_last;
    end
end


// Track boundaries in read data

reg  [9:0]      r_cnt;
assign          r_len_last      = (r_cnt == r_len);

always @(posedge clk) begin
    if(rst) begin
        r_cnt    <= 1;
    end else begin
        if(axi_r_ready && axi_r_valid && !r_len_last) begin
            r_cnt    <= r_cnt + 1;
        end
        if(rcb_ready && rcb_valid) begin
            r_cnt   <= 1;
        end
    end
end


// Aggregate read response

reg  [1:0]      r_resp;
wire [1:0]      r_resp_accum    = (axi_r_resp != AXI_RESP_OKAY) ? axi_r_resp : r_resp;

always @(posedge clk) begin
    if(rst) begin
        r_resp      <= AXI_RESP_OKAY;
    end else if(axi_r_ready && axi_r_valid) begin
        if(r_len_last) begin
            r_resp      <= AXI_RESP_OKAY;
        end else begin
            r_resp      <= r_resp_accum;
        end
    end
end


// Buffer response headers

dlsc_fifo_rvho #(
    .DATA           ( 7+10+12+1+2 ),
    .DEPTH          ( 16 ),
    .ALMOST_FULL    ( 1 )
) dlsc_fifo_rvho_cplh (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( axi_r_ready && axi_r_valid && r_len_last && !rd_flush ),
    .wr_data        ( {
        r_addr,
        r_len,
        r_bytes,
        r_last,
        r_resp_accum } ),
    .wr_full        (  ),
    .wr_almost_full ( resp_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( cpl_h_ready ),
    .rd_valid       ( cpl_h_valid ),
    .rd_data        ( {
        cpl_h_addr,
        cpl_h_len,
        cpl_h_bytes,
        cpl_h_last, 
        cpl_h_resp } ),
    .rd_almost_empty(  )
);


// Buffer read data

wire            rd_empty;
assign          cpl_d_valid     = !rd_empty;

dlsc_fifo #(
    .DATA               ( 1+32 ),
    .ADDR               ( BUFA )
) dlsc_fifo_rd (
    .clk                ( clk ),
    .rst                ( rst ),
    .wr_push            ( axi_r_ready && axi_r_valid ),
    .wr_data            ( { r_len_last, axi_r_data } ),
    .wr_full            (  ),
    .wr_almost_full     (  ),
    .rd_pop             ( cpl_d_ready && cpl_d_valid ),
    .rd_data            ( { cpl_d_last, cpl_d_data } ),
    .rd_empty           ( rd_empty ),
    .rd_almost_empty    (  ),
    .rd_count           (  )
);


// Allocate buffer space

reg  [BUFA:0]   mem_free;
wire [BUFA:0]   mem_free_sub    = mem_free - { {(BUFA-LEN){1'b0}}, cmd_len };
wire            mem_free_okay   = !mem_free_sub[BUFA];

wire            mem_rd          = cpl_d_ready && cpl_d_valid;

always @(posedge clk) begin
    if(rst) begin
        mem_free    <= (2**BUFA);
    end else begin
        if(cmd_ready && cmd_valid) begin
            mem_free    <= mem_free_sub + { {BUFA{1'b0}},  mem_rd };
        end else begin
            mem_free    <= mem_free     + { {BUFA{1'b0}},  mem_rd };
        end
    end
end


// Check MOT

localparam      MOTB            = `dlsc_clog2(MOT);
reg  [MOTB-1:0] mot_cnt;
reg             mot_max;
wire            mot_inc         = cmd_ready && cmd_valid;
wire            mot_dec         = axi_r_ready && axi_r_valid && axi_r_last;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin
        mot_cnt     <= 0;
        mot_max     <= 1'b0;
        rd_busy     <= 1'b0;
    end else begin
        if( mot_inc && !mot_dec) begin
            mot_cnt     <= mot_cnt + 1;
            mot_max     <= (mot_cnt == MOT-1);
            rd_busy     <= 1'b1;
        end
        if(!mot_inc &&  mot_dec) begin
            mot_cnt     <= mot_cnt - 1;
            mot_max     <= 1'b0;
            rd_busy     <= (mot_cnt != 1);
        end
    end
end
/* verilator lint_on WIDTH */


// Check token

wire [TOKN-1:0] token_sub       = token_wr - cmd_token;
wire            token_okay      = !token_sub[TOKN-1];

always @(posedge clk) begin
    if(rst) begin
        token_oldest    <= 0;
    end else begin
        if(cmd_ready && cmd_valid && cmd_last) begin
            // issued last transaction for this request; update oldest token
            token_oldest    <= cmd_token;
        end
        if(!cmd_valid && !axi_h_valid && !req_h_valid) begin
            // no pending requests; oldest token is same as last completed write
            token_oldest    <= token_wr;
        end
    end
end


// Handshaking

assign          cmd_ready       = (!axi_ar_valid || axi_ar_ready) && mem_free_okay &&
                                    token_okay && !mot_max && !rd_disable;


endmodule

