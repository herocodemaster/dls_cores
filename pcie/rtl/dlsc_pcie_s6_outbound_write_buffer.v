
module dlsc_pcie_s6_outbound_write_buffer #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MOT       = 16,
    parameter BUFA      = (LEN+1)                   // size of write combining buffer (>= LEN)
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // AXI write command input
    output  reg                 axi_aw_ready,
    input   wire                axi_aw_valid,
    input   wire    [ADDR-1:0]  axi_aw_addr,
    input   wire    [LEN-1:0]   axi_aw_len,

    // AXI write data input
    output  reg                 axi_w_ready,
    input   wire                axi_w_valid,
    input   wire                axi_w_last,
    input   wire    [3:0]       axi_w_strb,
    input   wire    [31:0]      axi_w_data,
    
    // AXI write response output
    input   wire                axi_b_ready,
    output  reg                 axi_b_valid,
    output  reg     [1:0]       axi_b_resp,

    // Write command to command splitter
    input   wire                cmd_aw_ready,
    output  wire                cmd_aw_valid,
    output  wire    [ADDR-1:2]  cmd_aw_addr,
    output  wire    [LEN-1:0]   cmd_aw_len,

    // Write data to command splitter
    input   wire                cmd_w_ready,
    output  wire                cmd_w_valid,
    output  wire    [3:0]       cmd_w_strb,
    
    // TLP payload output
    input   wire                tlp_d_ready,
    output  wire                tlp_d_valid,
    output  wire    [31:0]      tlp_d_data,
    output  wire                tlp_d_axi_last,

    // TLP payload acknowledge
    input   wire                tlp_d_axi_ack,

    // control/status
    output  wire                wr_busy,
    input   wire                wr_disable,
    input   wire                wr_flush
);

`include "dlsc_clog2.vh"

localparam  MOTB            = `dlsc_clog2(MOT);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;


// Track MOTs

reg  [MOTB-1:0] mot_cnt;
reg             mot_zero;
reg             mot_full;

reg  [MOTB-1:0] next_mot_cnt;
reg             next_mot_zero;
reg             next_mot_full;

wire            mot_inc         = (axi_aw_ready && axi_aw_valid);
wire            mot_dec         = (axi_b_ready && axi_b_valid);

assign          wr_busy         = !mot_zero;

always @* begin
    next_mot_cnt    = mot_cnt;
    next_mot_zero   = mot_zero;
    next_mot_full   = mot_full;
    if(mot_inc && !mot_dec) begin
        next_mot_cnt    = mot_cnt + 1;
        next_mot_zero   = 1'b0;
/* verilator lint_off WIDTH */
        next_mot_full   = (mot_cnt == (MOT-1));
/* verilator lint_on WIDTH */
    end
    if(!mot_inc && mot_dec) begin
        next_mot_cnt    = mot_cnt - 1;
        next_mot_zero   = (mot_cnt == 1);
        next_mot_full   = 1'b0;
    end
end

always @(posedge clk) begin
    if(rst) begin
        mot_cnt     <= 0;
        mot_zero    <= 1'b1;
        mot_full    <= 1'b0;
    end else begin
        mot_cnt     <= next_mot_cnt;
        mot_zero    <= next_mot_zero;
        mot_full    <= next_mot_full;
    end
end


// Track buffer space

reg  [BUFA:0]   buf_free;
reg  [BUFA:0]   next_buf_free;

always @* begin
    next_buf_free   = buf_free;
    if(axi_aw_ready && axi_aw_valid) begin
        next_buf_free   = next_buf_free - {{BUFA{1'b0}},1'b1} - { {(BUFA+1-LEN){1'b0}},axi_aw_len };
    end
    if(tlp_d_ready && tlp_d_valid) begin
        next_buf_free   = next_buf_free + {{BUFA{1'b0}},1'b1};
    end
end

always @(posedge clk) begin
    if(rst) begin
        buf_free    <= (2**BUFA);
    end else begin
        buf_free    <= next_buf_free;
    end
end


// Create AW ready
// (only want to accept commands for which we have room in the buffer)

wire            aw_almost_full;

always @(posedge clk) begin
    if(rst) begin
        axi_aw_ready    <= 1'b0;
    end else begin
        // only ready if we have room for a maximum size burst
        axi_aw_ready    <= |next_buf_free[BUFA:LEN] && !next_mot_full && !aw_almost_full && !wr_disable;
    end
end


// Buffer AW

dlsc_fifo_rvho #(
    .DATA           ( ADDR - 2 + LEN ),
    .DEPTH          ( 4 ),
    .ALMOST_FULL    ( 1 )
) dlsc_fifo_rvho_cmd_aw (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( axi_aw_ready && axi_aw_valid ),
    .wr_data        ( { axi_aw_addr[ADDR-1:2], axi_aw_len } ),
    .wr_full        (  ),
    .wr_almost_full ( aw_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( cmd_aw_ready ),
    .rd_valid       ( cmd_aw_valid ),
    .rd_data        ( { cmd_aw_addr, cmd_aw_len } ),
    .rd_almost_empty(  )
);


// Create W ready
// (only want to accept data for which we've already accepted the command)

reg  [MOTB-1:0] w_cnt;
wire            w_inc           = (axi_aw_ready && axi_aw_valid);
wire            w_dec           = (axi_w_ready && axi_w_valid && axi_w_last);

always @(posedge clk) begin
    if(rst) begin
        w_cnt       <= 0;
        axi_w_ready <= 1'b0;
    end else begin
        if(w_inc && !w_dec) begin
            w_cnt       <= w_cnt + 1;
            axi_w_ready <= 1'b1;
        end
        if(!w_inc && w_dec) begin
            w_cnt       <= w_cnt - 1;
            axi_w_ready <= (w_cnt != 1);
        end
    end
end


// Buffer W (for command splitter)

dlsc_fifo_rvho #(
    .DATA           ( 4 ),
    .ADDR           ( BUFA )
) dlsc_fifo_rvho_cmd_w (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( axi_w_ready && axi_w_valid ),
    .wr_data        ( axi_w_strb ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_ready       ( cmd_w_ready ),
    .rd_valid       ( cmd_w_valid ),
    .rd_data        ( cmd_w_strb ),
    .rd_almost_empty(  )
);


// Buffer W (for TLP payload)

wire            fifo_d_ready    = wr_flush ? 1'b1 : tlp_d_ready;
wire            fifo_d_valid;

assign          tlp_d_valid     = wr_flush ? 1'b0 : fifo_d_valid;

dlsc_fifo_rvho #(
    .DATA           ( 33 ),
    .ADDR           ( BUFA )
) dlsc_fifo_rvho_tlp_d (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( axi_w_ready && axi_w_valid ),
    .wr_data        ( { axi_w_last, axi_w_data } ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_ready       ( fifo_d_ready ),
    .rd_valid       ( fifo_d_valid ),
    .rd_data        ( { tlp_d_axi_last, tlp_d_data } ),
    .rd_almost_empty(  )
);


// Buffer B

reg  [MOTB-1:0] b_cnt;
reg             b_cnt_zero;

reg  [MOTB-1:0] next_b_cnt;
reg             next_b_cnt_zero;

wire            b_inc           = wr_flush ? (fifo_d_valid && tlp_d_axi_last) : tlp_d_axi_ack;
wire            b_dec           = (axi_b_ready && axi_b_valid) && !b_cnt_zero;

always @* begin
    next_b_cnt      = b_cnt;
    next_b_cnt_zero = b_cnt_zero;

    if(b_inc && !b_dec) begin
        next_b_cnt      = b_cnt + 1;
        next_b_cnt_zero = 1'b0;
    end
    if(!b_inc && b_dec) begin
        next_b_cnt      = b_cnt - 1;
        next_b_cnt_zero = (b_cnt == 1);
    end
end

always @(posedge clk) begin
    if(rst) begin
        b_cnt       <= 0;
        b_cnt_zero  <= 1'b1;
    end else begin
        b_cnt       <= next_b_cnt;
        b_cnt_zero  <= next_b_cnt_zero;
    end
end

always @(posedge clk) begin
    if(rst) begin
        axi_b_valid <= 1'b0;
        axi_b_resp  <= AXI_RESP_OKAY;
    end else if(axi_b_ready || !axi_b_valid) begin
        if(!next_b_cnt_zero) begin
            // successful completion under normal conditions; error when flushing
            axi_b_valid <= 1'b1;
            axi_b_resp  <= wr_flush ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
        end else begin
            // idle
            axi_b_valid <= 1'b0;
            axi_b_resp  <= AXI_RESP_OKAY;
        end
    end
end


endmodule

