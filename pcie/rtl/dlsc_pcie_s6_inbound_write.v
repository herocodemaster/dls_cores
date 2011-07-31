
module dlsc_pcie_s6_inbound_write #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter BUFA      = 8,
    parameter MOT       = 16,
    parameter TOKN      = 4
) (
    // System
    input   wire                clk,
    input   wire                rst,

    // Transaction ordering token interlock
    output  reg     [TOKN-1:0]  token_wr,
    
    // Request header from dispatcher
    output  wire                req_h_ready,
    input   wire                req_h_valid,
    input   wire                req_h_np,
    input   wire    [ADDR-1:2]  req_h_addr,
    input   wire    [9:0]       req_h_len,
    input   wire    [TOKN-1:0]  req_h_token,

    // Data from decoder
    output  wire                req_d_ready,
    input   wire                req_d_valid,
    input   wire    [31:0]      req_d_data,
    input   wire    [3:0]       req_d_strb,

    // Header to completer (non-posted only)
    input   wire                cpl_h_ready,
    output  reg                 cpl_h_valid,
    output  reg     [1:0]       cpl_h_resp,

    // Error reporting (posted only)
    input   wire                err_ready,
    output  reg                 err_valid,
    output  reg                 err_unsupported,

    // AXI write command
    input   wire                axi_aw_ready,
    output  reg                 axi_aw_valid,
    output  reg     [ADDR-1:0]  axi_aw_addr,
    output  reg     [LEN-1:0]   axi_aw_len,

    // AXI write data
    input   wire                axi_w_ready,
    output  reg                 axi_w_valid,
    output  reg                 axi_w_last,
    output  reg     [31:0]      axi_w_data,
    output  reg     [3:0]       axi_w_strb,

    // AXI write response
    output  wire                axi_b_ready,
    input   wire                axi_b_valid,
    input   wire    [1:0]       axi_b_resp
);

localparam  AXI_RESP_OKAY       = 2'b00,
            AXI_RESP_SLVERR     = 2'b10,
            AXI_RESP_DECERR     = 2'b11;

// limit AW requests to 1/2th of the buffer size
localparam  AW_MAX_SIZE_DW      = ((2**LEN) > ((2**BUFA)/2)) ? ((2**BUFA)/2) : (2**LEN);


// Buffer write data

wire            w_empty;
wire            w_full;
assign          req_d_ready     = !w_full;

wire            w_pop;
wire [3:0]      w_strb;
wire [31:0]     w_data;
wire [BUFA:0]   w_cnt;

dlsc_fifo #(
    .DATA           ( 4+32 ),
    .ADDR           ( BUFA ),
    .COUNT          ( 1 )
) dlsc_fifo_w (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( req_d_ready && req_d_valid ),
    .wr_data        ( { req_d_strb, req_d_data } ),
    .wr_full        ( w_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( w_pop ),
    .rd_data        ( { w_strb, w_data } ),
    .rd_empty       ( w_empty ),
    .rd_almost_empty(  ),
    .rd_count       ( w_cnt )
);


// Create AXI commands

wire            cmd_ready;
wire            cmd_valid;
wire [ADDR-1:2] cmd_addr;
wire [LEN:0]    cmd_len;
wire            cmd_np;
wire [TOKN-1:0] cmd_token;
wire            cmd_last;

dlsc_pcie_s6_cmdsplit #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN+1 ),
    .OUT_SUB        ( 0 ),
    .MAX_SIZE       ( AW_MAX_SIZE_DW*4 ),
    .ALIGN          ( 0 ),
    .META           ( TOKN+1 ),
    .REGISTER       ( 0 )
) dlsc_pcie_s6_cmdsplit_cmd (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( req_h_ready ),
    .in_valid       ( req_h_valid ),
    .in_addr        ( req_h_addr ),
    .in_len         ( req_h_len ),
    .in_meta        ( { req_h_np, req_h_token } ),
    .max_size       ( 3'b101 ), // 4K
    .out_ready      ( cmd_ready ),
    .out_valid      ( cmd_valid ),
    .out_addr       ( cmd_addr ),
    .out_len        ( cmd_len ),
    .out_meta       ( { cmd_np, cmd_token } ),
    .out_last       ( cmd_last )
);


// Buffer anticipated responses

wire            b_pop;
wire            b_full;

wire            b_np;
wire            b_last;
wire [TOKN-1:0] b_token;

dlsc_fifo #(
    .DATA           ( TOKN+2 ),
    .DEPTH          ( MOT )
) dlsc_fifo_b (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( cmd_ready && cmd_valid ),
    .wr_data        ( { cmd_np, cmd_token, cmd_last } ),
    .wr_full        ( b_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( b_pop ),
    .rd_data        ( { b_np, b_token, b_last } ),
    .rd_empty       (  ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);


// Aggregate write response

reg  [1:0]      resp;
wire [1:0]      resp_accum      = (axi_b_resp != AXI_RESP_OKAY) ? axi_b_resp : resp;

assign          b_pop           = (axi_b_ready && axi_b_valid);

always @(posedge clk) begin
    if(rst) begin
        resp        <= AXI_RESP_OKAY;
    end else if(b_pop) begin
        if(b_last) begin
            resp        <= AXI_RESP_OKAY;
        end else begin
            resp        <= resp_accum;
        end
    end
end


// Drive token

always @(posedge clk) begin
    if(rst) begin
        token_wr    <= 0;
    end else if(b_pop && b_last) begin
        token_wr    <= b_token;
    end
end


// Buffer completion headers

wire            ch_full;
assign          axi_b_ready     = !ch_full;

wire            ch_empty;
wire            ch_pop;
wire [1:0]      ch_resp;
wire            ch_np;

dlsc_fifo #(
    .DATA           ( 3 ),
    .DEPTH          ( 4 )
) dlsc_fifo_cplh (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( b_pop && b_last ),
    .wr_data        ( { b_np, resp_accum } ),
    .wr_full        ( ch_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( ch_pop ),
    .rd_data        ( { ch_np, ch_resp } ),
    .rd_empty       ( ch_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);


// Drive completion headers/errors

assign          ch_pop          = !ch_empty && !cpl_h_valid && !err_valid;

always @(posedge clk) begin
    if(rst) begin
        cpl_h_valid     <= 1'b0;
        err_valid       <= 1'b0;
    end else begin
        if(cpl_h_ready)
            cpl_h_valid     <= 1'b0;
        if(err_ready)
            err_valid       <= 1'b0;
        if(ch_pop) begin
            cpl_h_valid     <= ch_np;
            err_valid       <= !ch_np && (ch_resp != AXI_RESP_OKAY);
        end
    end
end

always @(posedge clk) begin
    if(ch_pop) begin
        cpl_h_resp      <= ch_resp;
        err_unsupported <= (ch_resp != AXI_RESP_OKAY);
    end
end


// Drive write command and data

localparam      CMPB            = ((LEN>BUFA) ? LEN : BUFA) + 1;

reg             data_first;
reg  [LEN:0]    data_cnt;
wire            data_last       = (cmd_len == data_cnt);

wire            cmd_okay        = cmd_valid && !b_full && !w_empty && ( {{(CMPB-LEN){1'b0}},cmd_len} <= {{(CMPB-BUFA){1'b0}},w_cnt} );

assign          w_pop           = ((!axi_aw_valid && cmd_okay) || !data_first) && (!axi_w_valid || axi_w_ready);

assign          cmd_ready       = w_pop && data_last;

always @(posedge clk) begin
    if(rst) begin
        data_first     <= 1'b1;
    end else if(w_pop) begin
        data_first      <= data_last;
    end
end

always @(posedge clk) begin
    if(rst) begin
        data_cnt    <= 1;
    end else if(w_pop) begin
        if(data_last) begin
            data_cnt    <= 1;
        end else begin
            data_cnt    <= data_cnt + 1;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        axi_w_valid     <= 1'b0;
        axi_aw_valid    <= 1'b0;
    end else begin
        if(axi_w_ready)  axi_w_valid  <= 1'b0;
        if(axi_aw_ready) axi_aw_valid <= 1'b0;
        if(w_pop) begin
            axi_w_valid <= 1'b1;
            if(data_first)
                axi_aw_valid <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(w_pop && data_first) begin
        axi_aw_addr     <= { cmd_addr, 2'b00 };
        axi_aw_len      <= cmd_len[LEN-1:0] - 1;
    end
end

always @(posedge clk) begin
    if(w_pop) begin
        axi_w_data      <= w_data;
        axi_w_strb      <= w_strb;
        axi_w_last      <= data_last;
    end
end

endmodule

