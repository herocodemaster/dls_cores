
module dlsc_axi_to_wb #(
    parameter WB_PIPELINE   = 0,    // use pipelined wishbone protocol
    parameter DATA          = 32,
    parameter ADDR          = 32,
    parameter LEN           = 4,
    parameter RESP          = 2,
    // derived; don't touch
    parameter STRB          = (DATA/8)
) (

    // system
    input   wire                    clk,
    input   wire                    rst,


    // ** AXI **

    // read command
    output  wire                    axi_ar_ready,
    input   wire                    axi_ar_valid,
    input   wire    [ADDR-1:0]      axi_ar_addr,
    input   wire    [LEN-1:0]       axi_ar_len,

    // read data/response
    input   wire                    axi_r_ready,
    output  reg                     axi_r_valid,
    output  reg                     axi_r_last,
    output  reg     [DATA-1:0]      axi_r_data,
    output  reg     [RESP-1:0]      axi_r_resp,

    // write command
    output  wire                    axi_aw_ready,
    input   wire                    axi_aw_valid,
    input   wire    [ADDR-1:0]      axi_aw_addr,
    input   wire    [LEN-1:0]       axi_aw_len,

    // write data
    output  wire                    axi_w_ready,
    input   wire                    axi_w_valid,
    input   wire                    axi_w_last,
    input   wire    [DATA-1:0]      axi_w_data,
    input   wire    [STRB-1:0]      axi_w_strb,

    // write response
    input   wire                    axi_b_ready,
    output  reg                     axi_b_valid,
    output  reg     [RESP-1:0]      axi_b_resp,


    // ** Wishbone **

    // cycle
    output  wire                    wb_cyc_o,

    // address
    output  reg                     wb_stb_o,
    output  reg                     wb_we_o,
    output  reg     [ADDR-1:0]      wb_adr_o,
    output  reg     [2:0]           wb_cti_o,   // incrementing (3'b010) or end (3'b111)

    // data
    output  reg     [DATA-1:0]      wb_dat_o,
    output  reg     [STRB-1:0]      wb_sel_o,

    // response
    input   wire                    wb_stall_i, // pipelined only
    input   wire                    wb_ack_i,
    input   wire                    wb_err_i,
    input   wire    [DATA-1:0]      wb_dat_i
);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;

localparam  WB_CTI_INCR     = 3'b010,
            WB_CTI_END      = 3'b111;

localparam  CMD_FIFO_DEPTH  = 12;
localparam  RESP_FIFO_DEPTH = 16;


// ** decouple write data **

reg             axi_w_ready_r;
wire            axi_w_valid_r;
wire            axi_w_last_r;
wire [DATA-1:0] axi_w_data_r;
wire [STRB-1:0] axi_w_strb_r;

dlsc_rvh_decoupler #(
    .WIDTH      ( DATA+STRB+1 )
) dlsc_rvh_decoupler_w (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_en      ( 1'b1 ),
    .in_ready   ( axi_w_ready ),
    .in_valid   ( axi_w_valid ),
    .in_data    ( { axi_w_last  , axi_w_data  , axi_w_strb   } ),
    .out_en     ( 1'b1 ),
    .out_ready  ( axi_w_ready_r ),
    .out_valid  ( axi_w_valid_r ),
    .out_data   ( { axi_w_last_r, axi_w_data_r, axi_w_strb_r } )
);


// ** command arbitration / registering **

reg  [ADDR-1:0] axi_cmd_addr        = 0;
reg  [LEN -1:0] axi_cmd_len         = 0;
reg             axi_cmd_len_zero    = 1'b1;
reg             axi_cmd_wr          = 1'b0;
reg             axi_cmd_valid       = 1'b0;
reg             axi_cmd_ready;

assign          axi_ar_ready        = !axi_cmd_valid && axi_ar_valid && ( axi_cmd_wr || !axi_aw_valid);
assign          axi_aw_ready        = !axi_cmd_valid && axi_aw_valid && (!axi_cmd_wr || !axi_ar_valid);

always @(posedge clk) begin
    if(rst || axi_cmd_ready) begin
        axi_cmd_valid       <= 1'b0;
    end else if(!axi_cmd_valid) begin
        axi_cmd_valid       <= axi_ar_valid || axi_aw_valid;
    end
end

always @(posedge clk) begin
    if(!axi_cmd_valid) begin
        axi_cmd_wr          <= axi_ar_ready ?  1'b0             :  1'b1;
        axi_cmd_addr        <= axi_ar_ready ?  axi_ar_addr      :  axi_aw_addr;
        axi_cmd_len         <= axi_ar_ready ?  axi_ar_len       :  axi_aw_len;
        axi_cmd_len_zero    <= axi_ar_ready ? (axi_ar_len == 0) : (axi_aw_len == 0);
    end
end


// ** command / write data **

wire            wb_cmd_ack          = (WB_PIPELINE == 0) ? wb_ack_i : !wb_stall_i;
wire            wb_resp_xfer        = (WB_PIPELINE == 0) ? (wb_ack_i && wb_stb_o) : (wb_ack_i && wb_cyc_o);

wire            next_stall;
wire            next_ready          = !next_stall && (!wb_stb_o || wb_cmd_ack);

reg             next_valid;

reg             next_we_o;
reg  [ADDR-1:0] next_adr_o;
reg  [2:0]      next_cti_o;

reg  [DATA-1:0] next_dat_o;
reg  [STRB-1:0] next_sel_o;

reg             next_last;
reg  [LEN-1:0]  next_cnt;

reg             wb_last;
reg  [LEN-1:0]  wb_cnt;

always @* begin
    if(wb_last) begin
        // get new command
        next_we_o       = axi_cmd_wr;
        next_adr_o      = axi_cmd_addr;
        next_cti_o      = axi_cmd_len_zero ? WB_CTI_END : WB_CTI_INCR;
        next_last       = axi_cmd_len_zero;
        next_cnt        = axi_cmd_len;
        next_dat_o      = axi_w_data_r;
        next_sel_o      = axi_cmd_wr ? axi_w_strb_r : {STRB{1'b1}};
    end else begin
        // update existing command
        next_we_o       = wb_we_o;
        next_adr_o      = wb_adr_o;
/* verilator lint_off WIDTH */
        next_adr_o[11:0]= wb_adr_o[11:0] + STRB;
/* verilator lint_on WIDTH */
        next_cti_o      = (wb_cnt == 1) ? WB_CTI_END : WB_CTI_INCR;
        next_last       = (wb_cnt == 1);
        next_cnt        = wb_cnt - 1;
        next_dat_o      = axi_w_data_r;
        next_sel_o      = wb_we_o ? axi_w_strb_r : {STRB{1'b1}};
    end
end

always @* begin
    if(wb_last) begin
        // get new command
        axi_w_ready_r   = next_ready && axi_cmd_valid && axi_cmd_wr;
        axi_cmd_ready   = next_ready && (axi_w_valid_r || !axi_cmd_wr);
        next_valid      = axi_cmd_valid && (axi_w_valid_r || !axi_cmd_wr);
    end else begin
        // update existing command
        axi_w_ready_r   = next_ready && wb_we_o;
        axi_cmd_ready   = 1'b0;
        next_valid      = axi_w_valid_r || !wb_we_o;
    end
end

always @(posedge clk) begin
    if(next_ready) begin
        wb_we_o     <= next_we_o;
        wb_adr_o    <= next_adr_o;
        wb_cti_o    <= next_cti_o;
        wb_dat_o    <= next_dat_o;
        wb_sel_o    <= next_sel_o;
    end
end

always @(posedge clk) begin
    if(rst) begin
        wb_last     <= 1'b1;
        wb_cnt      <= 0;
    end else if(next_ready && next_valid) begin
        wb_last     <= next_last;
        wb_cnt      <= next_cnt;
    end
end

reg             next_stb_o;

always @* begin
    next_stb_o  = wb_stb_o;
    if(wb_cmd_ack) begin
        // de-assert command when acknowledged
        next_stb_o  = 1'b0;
    end
    if(next_ready) begin
        // assert command when one is wanted (ready) and available (valid)
        next_stb_o  = next_valid;
    end
end

always @(posedge clk) begin
    if(rst) begin
        wb_stb_o    <= 1'b0;
    end else begin
        wb_stb_o    <= next_stb_o;
    end
end


// command tracking

wire            fifo_cmd_wr;
wire            fifo_cmd_last;

wire            fifo_cmd_empty;
wire            fifo_cmd_full;

wire            fifo_cmd_push_en    = next_ready && next_valid;
wire            fifo_cmd_pop_en     = wb_resp_xfer;

assign          wb_cyc_o            = !fifo_cmd_empty;

dlsc_fifo_shiftreg #(
    .DATA           ( 2 ),
    .DEPTH          ( CMD_FIFO_DEPTH )
) dlsc_fifo_shiftreg_cmd (
    .clk            ( clk ),
    .rst            ( rst ),
    .push_en        ( fifo_cmd_push_en ),
    .push_data      ( { next_we_o, next_last } ),
    .pop_en         ( fifo_cmd_pop_en ),
    .pop_data       ( { fifo_cmd_wr, fifo_cmd_last } ),
    .empty          ( fifo_cmd_empty ),
    .full           ( fifo_cmd_full ),
    .almost_empty   (  ),
    .almost_full    (  )
);


// response accumulate

reg  [RESP-1:0] wb_resp_accum;
wire [RESP-1:0] wb_resp_accum_next = wb_err_i ? AXI_RESP_SLVERR : wb_resp_accum;

always @(posedge clk) begin
    if(rst) begin
        wb_resp_accum   <= AXI_RESP_OKAY;
    end else if(wb_resp_xfer) begin
        wb_resp_accum   <= fifo_cmd_last ? AXI_RESP_OKAY : wb_resp_accum_next;
    end
end


// response buffering

wire            fifo_resp_wr;
wire            fifo_resp_last;
wire [DATA-1:0] fifo_resp_data;
wire [RESP-1:0] fifo_resp_resp;

wire            fifo_resp_empty;
wire            fifo_resp_full;

wire            fifo_resp_push_en   = wb_resp_xfer && ( !fifo_cmd_wr || fifo_cmd_last );
wire            fifo_resp_pop_en    = !fifo_resp_empty && ( fifo_resp_wr ?
                                        (!axi_b_valid || axi_b_ready) :
                                        (!axi_r_valid || axi_r_ready) ); 
dlsc_fifo_shiftreg #(
    .DATA           ( DATA+RESP+2 ),
    .DEPTH          ( RESP_FIFO_DEPTH ),
    .ALMOST_FULL    ( CMD_FIFO_DEPTH )
) dlsc_fifo_shiftreg_resp (
    .clk            ( clk ),
    .rst            ( rst ),
    .push_en        ( fifo_resp_push_en ),
    .push_data      ( {
        wb_dat_i,
        wb_resp_accum_next,
        fifo_cmd_last,
        fifo_cmd_wr } ),
    .pop_en         ( fifo_resp_pop_en ),
    .pop_data       ( {
        fifo_resp_data,
        fifo_resp_resp,
        fifo_resp_last,
        fifo_resp_wr } ),
    .empty          ( fifo_resp_empty ),
    .full           (  ),
    .almost_empty   (  ),
    .almost_full    ( fifo_resp_full )
);


// read response

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid     <= 1'b0;
    end else begin
        if(axi_r_ready) begin
            axi_r_valid     <= 1'b0;
        end
        if(fifo_resp_pop_en && !fifo_resp_wr) begin
            axi_r_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(fifo_resp_pop_en && !fifo_resp_wr) begin
        axi_r_last      <= fifo_resp_last;
        axi_r_data      <= fifo_resp_data;
        axi_r_resp      <= fifo_resp_resp;
    end
end


// write response

always @(posedge clk) begin
    if(rst) begin
        axi_b_valid     <= 1'b0;
    end else begin
        if(axi_b_ready) begin
            axi_b_valid     <= 1'b0;
        end
        if(fifo_resp_pop_en && fifo_resp_wr) begin
            axi_b_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(fifo_resp_pop_en && fifo_resp_wr) begin
        axi_b_resp      <= fifo_resp_resp;
    end
end


// stall if any FIFOs are full
assign          next_stall          = fifo_cmd_full || fifo_resp_full;


endmodule

