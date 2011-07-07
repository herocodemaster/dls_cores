
module dlsc_pcie_s6_outbound_write_core #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MAX_SIZE  = 128                       // maximum write payload size
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,


    // ** AXI **

    // Write Command
    output  wire                axi_aw_ready,
    input   wire                axi_aw_valid,
    input   wire    [ADDR-1:0]  axi_aw_addr,
    input   wire    [LEN-1:0]   axi_aw_len,

    // Write Data
    output  wire                axi_w_ready,
    input   wire                axi_w_valid,
    input   wire                axi_w_last,
    input   wire    [3:0]       axi_w_strb,
    input   wire    [31:0]      axi_w_data,

    // Write Response
    input   wire                axi_b_ready,
    output  reg                 axi_b_valid,
    output  wire    [1:0]       axi_b_resp,


    // ** PCIe **

    // Config
    input   wire    [2:0]       max_payload_size,   // 128, 256, 512, 1024, 2048, 4096 (must be <= MAX_SIZE)

    // TLP header
    input   wire                tlp_h_ready,
    output  reg                 tlp_h_valid,
    output  reg     [ADDR-1:2]  tlp_h_addr,
    output  reg     [9:0]       tlp_h_len,
    output  reg     [3:0]       tlp_h_be_first,
    output  reg     [3:0]       tlp_h_be_last,

    // TLP payload
    input   wire                tlp_d_ready,
    output  reg                 tlp_d_valid,
    output  reg     [31:0]      tlp_d_data
);

`include "dlsc_clog2.vh"

localparam MOT          = 15;
localparam MOTB         = `dlsc_clog2(MOT);


// ** Buffer write response (B) **

reg  [MOTB-1:0] axi_b_cnt   = 0;

wire            axi_b_inc;
wire            axi_b_dec   = axi_b_ready && axi_b_valid;

assign          axi_b_resp  = 2'b00;    // always OKAY

always @(posedge clk) begin
    if(rst) begin
        axi_b_cnt       <= 0;
        axi_b_valid     <= 1'b0;
    end else begin
        if( axi_b_inc && !axi_b_dec) begin
            axi_b_cnt       <= axi_b_cnt + 1;
            axi_b_valid     <= 1'b1;
        end
        if(!axi_b_inc &&  axi_b_dec) begin
            axi_b_cnt       <= axi_b_cnt - 1;
            axi_b_valid     <= (axi_b_cnt != 1);
        end
    end
end


// ** Buffer write data (W) **

// Strobes

wire            axi_w_ready_s;
wire            axi_w_valid_s;
reg             axi_w_ready_r;
wire            axi_w_valid_r;
wire [3:0]      axi_w_strb_r;

dlsc_rvh_decoupler #(
    .WIDTH          ( 4 )
) dlsc_rvh_decoupler_w_strb (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_en          ( 1'b1 ),
    .in_ready       ( axi_w_ready_s ),
    .in_valid       ( axi_w_valid_s ),
    .in_data        ( axi_w_strb ),
    .out_en         ( 1'b1 ),
    .out_ready      ( axi_w_ready_r ),
    .out_valid      ( axi_w_valid_r ),
    .out_data       ( axi_w_strb_r )
);

// Data

wire            fifo_w_empty;
wire            fifo_w_full;
wire            fifo_w_push     = axi_w_ready && axi_w_valid;
wire            fifo_w_pop      = !fifo_w_empty && (!tlp_d_valid || tlp_d_ready);
wire            fifo_w_last;
wire [31:0]     fifo_w_data;

assign          axi_w_ready     = !fifo_w_full && axi_w_ready_s;
assign          axi_w_valid_s   = !fifo_w_full && axi_w_valid;

// TODO: shiftreg isn't efficient for large MAX_SIZE
dlsc_fifo_shiftreg #(
    .DATA           ( 33 ),
    .DEPTH          ( MAX_SIZE/4 + 16 )
) dlsc_fifo_shiftreg_w (
    .clk            ( clk ),
    .rst            ( rst ),
    .push_en        ( fifo_w_push ),
    .push_data      ( { axi_w_last, axi_w_data } ),
    .pop_en         ( fifo_w_pop ),
    .pop_data       ( { fifo_w_last, fifo_w_data } ),
    .empty          ( fifo_w_empty ),
    .full           ( fifo_w_full ),
    .almost_empty   (  ),
    .almost_full    (  )
);

always @(posedge clk) begin
    if(rst) begin
        tlp_d_valid     <= 1'b0;
    end else begin
        if(tlp_d_ready) begin
            tlp_d_valid     <= 1'b0;
        end
        if(fifo_w_pop) begin
            tlp_d_valid     <= 1'b1;
        end
    end
end

// only generate response once last beat of data is accepted by downstream
// (implying that it is now impossible for a subsequent read command to pass it)
reg             d_last          = 0;    // AXI last; not necessarily TLP last
assign          axi_b_inc       = (tlp_d_ready && tlp_d_valid && d_last);

always @(posedge clk) begin
    if(fifo_w_pop) begin
        d_last          <= fifo_w_last;
        tlp_d_data      <= fifo_w_data;
    end
end


// ** Buffer write command (AW) **

reg             axi_aw_ready_r;
wire            axi_aw_valid_r;
wire [ADDR-1:0] axi_aw_addr_r;
wire [LEN-1:0]  axi_aw_len_r;

dlsc_rvh_decoupler #(
    .WIDTH          ( ADDR + LEN )
) dlsc_rvh_decoupler_aw (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_en          ( 1'b1 ),
    .in_ready       ( axi_aw_ready ),
    .in_valid       ( axi_aw_valid ),
    .in_data        ( { axi_aw_addr, axi_aw_len } ),
    .out_en         ( 1'b1 ),
    .out_ready      ( axi_aw_ready_r ),
    .out_valid      ( axi_aw_valid_r ),
    .out_data       ( { axi_aw_addr_r, axi_aw_len_r } )
);

// track count of outstanding transactions
// (so we don't accept more commands than we can buffer responses for)

reg  [MOTB-1:0] mot_cnt     = 0;
reg             mot_max     = 0;

wire            mot_inc     = axi_aw_ready_r && axi_aw_valid_r;
wire            mot_dec     = axi_b_dec;

always @(posedge clk) begin
    if(rst) begin
        mot_cnt         <= 0;
        mot_max         <= 1'b0;
    end else begin
        if( mot_inc && !mot_dec) begin
            mot_cnt         <= mot_cnt + 1;
/* verilator lint_off WIDTH */
            mot_max         <= (mot_cnt == (MOT-1));
/* verilator lint_on WIDTH */
        end
        if(!mot_inc &&  mot_dec) begin
            mot_cnt         <= mot_cnt - 1;
            mot_max         <= 1'b0;
        end
    end
end


// ** Buffer TLP headers **

wire            fifo_h_empty;
wire            fifo_h_full;
wire            fifo_h_push;
wire            fifo_h_pop      = !fifo_h_empty && (!tlp_h_valid || tlp_h_ready);

wire [ADDR+15:0] fifo_h_push_data;
wire [ADDR+15:0] fifo_h_pop_data;

dlsc_fifo_shiftreg #(
    .DATA           ( ADDR + 16 ),
    .DEPTH          ( 16 )
) dlsc_fifo_shiftreg_tlp_h (
    .clk            ( clk ),
    .rst            ( rst ),
    .push_en        ( fifo_h_push ),
    .push_data      ( fifo_h_push_data ),
    .pop_en         ( fifo_h_pop ),
    .pop_data       ( fifo_h_pop_data ),
    .empty          ( fifo_h_empty ),
    .full           ( fifo_h_full ),
    .almost_empty   (  ),
    .almost_full    (  )
);

always @(posedge clk) begin
    if(rst) begin
        tlp_h_valid     <= 1'b0;
    end else begin
        if(tlp_h_ready) begin
            tlp_h_valid     <= 1'b0;
        end
        if(fifo_h_pop) begin
            tlp_h_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(fifo_h_pop) begin
        { tlp_h_addr,
          tlp_h_len,
          tlp_h_be_first,
          tlp_h_be_last }   <= fifo_h_pop_data;
    end
end


// ** Create command stream **

wire            cmd_ready;
reg             cmd_valid       = 0;

reg             next_cmd_valid;

wire            cmd_update      = next_cmd_valid && (!cmd_valid || cmd_ready);

reg  [3:0]      cmd_strb        = 0;
reg  [ADDR-1:2] cmd_addr        = 0;
reg  [ADDR-1:2] cmd_addr_p1     = 1;
reg             cmd_addr_cont   = 0;
reg  [LEN-1:0]  cmd_len         = 0;
reg             cmd_len_zero    = 1;

reg  [ADDR-1:2] next_cmd_addr;
reg             next_cmd_addr_cont;
reg  [LEN-1:0]  next_cmd_len;
reg             next_cmd_len_zero;

always @* begin
    if(cmd_len_zero) begin
        next_cmd_addr       = axi_aw_addr_r[ADDR-1:2];
        next_cmd_addr_cont  = (axi_aw_addr_r[ADDR-1:2] == cmd_addr_p1) && (cmd_addr_p1[11:2] != 10'd0);
        next_cmd_len        = axi_aw_len_r;
        next_cmd_len_zero   = (axi_aw_len_r == 0);
    end else begin
        next_cmd_addr       = cmd_addr_p1;
        next_cmd_addr_cont  = 1'b1;
        next_cmd_len        = cmd_len - 1;
        next_cmd_len_zero   = (cmd_len == 1);
    end
end

always @* begin
    if(cmd_len_zero) begin
        next_cmd_valid      = axi_w_valid_r && axi_aw_valid_r && !mot_max;
    end else begin
        next_cmd_valid      = axi_w_valid_r;
    end
end

always @* begin
    if(cmd_len_zero) begin
        axi_w_ready_r       = cmd_update;
        axi_aw_ready_r      = cmd_update;
    end else begin
        axi_w_ready_r       = cmd_update;
        axi_aw_ready_r      = 1'b0;
    end
end

always @(posedge clk) begin
    if(rst) begin
        cmd_valid       <= 1'b0;
    end else begin
        if(cmd_ready) begin
            cmd_valid       <= 1'b0;
        end
        if(cmd_update) begin
            cmd_valid       <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        cmd_len_zero    <= 1'b1;
    end else if(cmd_update) begin
        cmd_len_zero    <= next_cmd_len_zero;
    end
end

always @(posedge clk) begin
    if(cmd_update) begin
        cmd_strb        <= axi_w_strb_r;
        cmd_addr        <= next_cmd_addr;
        cmd_addr_p1     <= { next_cmd_addr[ADDR-1:12], (next_cmd_addr[11:2] + 10'd1) };
        cmd_addr_cont   <= next_cmd_addr_cont;
        cmd_len         <= next_cmd_len;
    end
end


// ** Create TLP headers **

reg             tlp_valid       = 0;

reg  [ADDR-1:2] tlp_addr        = 0;
reg  [9:0]      tlp_len         = 0;
reg             tlp_len_one     = 0;
reg             tlp_len_max     = 0;
reg  [3:0]      tlp_be_first    = 0;
reg  [3:0]      tlp_be_last     = 0;

reg             tlp_cmd_last    = 0;

reg             next_tlp_len_max;

assign          fifo_h_push_data = {
                    tlp_addr,
                    tlp_len,
                    tlp_be_first,
                    tlp_be_last };

reg             tlp_can_merge;

always @* begin
    tlp_can_merge       = 1'b0;

    if(cmd_addr_cont && !tlp_len_max) begin
        if( (tlp_be_first == 4'hF || tlp_be_first == 4'hE || tlp_be_first == 4'hC || tlp_be_first == 4'h8) &&
            (cmd_strb     == 4'hF || cmd_strb     == 4'h7 || cmd_strb     == 4'h3 || cmd_strb     == 4'h1) &&
            (tlp_len_one || tlp_be_last == 4'hF) )
        begin
            // contiguous
            tlp_can_merge       = 1'b1;
        end

        if(tlp_be_first != 4'h0 && cmd_strb != 4'h0 && tlp_len_one && tlp_addr[2] == 1'b0) begin
            // special case: QW aligned write allows sparse strobes
            tlp_can_merge       = 1'b1;
        end
    end
end

assign          cmd_ready       = !tlp_valid || tlp_can_merge;

// we'll push when the next command can't be merged, or if the command path is throttling (but only on command boundaries)
assign          fifo_h_push     = !fifo_h_full && tlp_valid && ( (cmd_valid && !tlp_can_merge) || (!cmd_valid && tlp_cmd_last) );

wire            tlp_update      = cmd_ready && cmd_valid;

always @(posedge clk) begin
    if(rst) begin
        tlp_valid       <= 1'b0;
    end else begin
        if(fifo_h_push) begin
            tlp_valid       <= 1'b0;
        end
        if(tlp_update) begin
            tlp_valid       <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(tlp_update) begin
        tlp_cmd_last    <= cmd_len_zero;
        if(!tlp_valid) begin
            tlp_addr        <= cmd_addr;
            tlp_len         <= 1;
            tlp_len_one     <= 1'b1;
            tlp_len_max     <= 1'b0;
            tlp_be_first    <= cmd_strb;
            tlp_be_last     <= 4'h0;
        end else begin
//          tlp_addr        <= tlp_addr;
            tlp_len         <= tlp_len + 1;
            tlp_len_one     <= 1'b0;
            tlp_len_max     <= next_tlp_len_max;
//          tlp_be_first    <= tlp_be_first;
            tlp_be_last     <= cmd_strb;
        end
    end
end

always @* begin
    next_tlp_len_max    = 1'b0;
    if( (MAX_SIZE == 128  || max_payload_size == 3'b000) && (&tlp_len[4:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 256  || max_payload_size == 3'b001) && (&tlp_len[5:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 512  || max_payload_size == 3'b010) && (&tlp_len[6:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 1024 || max_payload_size == 3'b011) && (&tlp_len[7:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 2048 || max_payload_size == 3'b100) && (&tlp_len[8:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 4096 || max_payload_size == 3'b101) && (&tlp_len[9:0])) next_tlp_len_max = 1'b1;
end


endmodule

