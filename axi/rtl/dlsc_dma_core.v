
module dlsc_dma_core #(
    // Command port
    parameter APB_ADDR          = 32,
    parameter CMD_ADDR          = 32,
    parameter CMD_LEN           = 4,

    // Read port
    parameter READ_ADDR         = 32,
    parameter READ_LEN          = 4,
    parameter READ_MOT          = 16,

    // Write port
    parameter WRITE_ADDR        = 32,
    parameter WRITE_LEN         = 4,
    parameter WRITE_MOT         = 16,

    // Common
    parameter DATA              = 32,
    parameter BUFFER_SIZE       = ((2**READ_LEN)*READ_MOT),
    parameter TRIGGERS          = 8
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Interrupt
    output  wire                    int_out,

    // Triggers
    input   wire    [TRIGGERS-1:0]  trig_in,
    output  wire    [TRIGGERS-1:0]  trig_in_ack,
    output  wire    [TRIGGERS-1:0]  trig_out,
    input   wire    [TRIGGERS-1:0]  trig_out_ack,

    // APB register access
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire    [31:0]          apb_wdata,
    output  wire    [31:0]          apb_rdata,
    output  wire                    apb_ready,

    // ** Command port **

    // AXI read command
    input   wire                    cmd_ar_ready,
    output  wire                    cmd_ar_valid,
    output  wire    [CMD_ADDR-1:0]  cmd_ar_addr,
    output  wire    [CMD_LEN-1:0]   cmd_ar_len,

    // AXI read data
    output  wire                    cmd_r_ready,
    input   wire                    cmd_r_valid,
    input   wire                    cmd_r_last,
    input   wire    [31:0]          cmd_r_data,
    input   wire    [1:0]           cmd_r_resp,

    // ** Read port **

    // AXI read command
    input   wire                    rd_ar_ready,
    output  wire                    rd_ar_valid,
    output  wire    [READ_ADDR-1:0] rd_ar_addr,
    output  wire    [READ_LEN-1:0]  rd_ar_len,

    // AXI read data
    output  wire                    rd_r_ready,
    input   wire                    rd_r_valid,
    input   wire                    rd_r_last,
    input   wire    [DATA-1:0]      rd_r_data,
    input   wire    [1:0]           rd_r_resp,

    // ** Write port **

    // AXI write command
    input   wire                    wr_aw_ready,
    output  wire                    wr_aw_valid,
    output  wire    [WRITE_ADDR-1:0] wr_aw_addr,
    output  wire    [WRITE_LEN-1:0] wr_aw_len,

    // AXI write data
    input   wire                    wr_w_ready,
    output  wire                    wr_w_valid,
    output  wire                    wr_w_last,
    output  wire    [(DATA/8)-1:0]  wr_w_strb,
    output  wire    [DATA-1:0]      wr_w_data,

    // AXI write response
    output  wire                    wr_b_ready,
    input   wire                    wr_b_valid,
    input   wire    [1:0]           wr_b_resp
);

`include "dlsc_clog2.vh"

localparam LSB  = `dlsc_clog2(DATA/8);
localparam BUFA = `dlsc_clog2(BUFFER_SIZE);


// ** Registers **

// System
wire                    rst_dma;
// Command block
wire                    cmd_apb_sel;
wire                    cmd_halt;
wire    [1:0]           cmd_error;
wire                    cmd_busy;
// Command block FIFO status
wire    [7:0]           frd_free;
wire                    frd_full;
wire                    frd_empty;
wire                    frd_almost_empty;
wire    [7:0]           fwr_free;
wire                    fwr_full;
wire                    fwr_empty;
wire                    fwr_almost_empty;
// Read block
wire                    rd_halt;
wire    [1:0]           rd_error;
wire                    rd_busy;
wire                    rd_cmd_done;
wire    [TRIGGERS-1:0]  rd_trig_in;
wire    [TRIGGERS-1:0]  rd_trig_ack;
wire    [TRIGGERS-1:0]  rd_trig_out;
// Write block
wire                    wr_halt;
wire    [1:0]           wr_error;
wire                    wr_busy;
wire                    wr_cmd_done;
wire    [TRIGGERS-1:0]  wr_trig_in;
wire    [TRIGGERS-1:0]  wr_trig_ack;
wire    [TRIGGERS-1:0]  wr_trig_out;

dlsc_dma_registers #(
    .TRIG               ( TRIGGERS )
) dlsc_dma_registers_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .rst_dma            ( rst_dma ),
    .apb_sel            ( apb_sel ),
    .apb_enable         ( apb_enable ),
    .apb_write          ( apb_write ),
    .apb_addr           ( apb_addr[5:2] ),
    .apb_wdata          ( apb_wdata ),
    .apb_rdata          ( apb_rdata ),
    .apb_ready          ( apb_ready ),
    .trig_in            ( trig_in ),
    .trig_in_ack        ( trig_in_ack ),
    .trig_out           ( trig_out ),
    .trig_out_ack       ( trig_out_ack ),
    .int_out            ( int_out ),
    .cmd_apb_sel        ( cmd_apb_sel ),
    .cmd_halt           ( cmd_halt ),
    .cmd_error          ( cmd_error ),
    .cmd_busy           ( cmd_busy ),
    .frd_free           ( frd_free ),
    .frd_full           ( frd_full ),
    .frd_empty          ( frd_empty ),
    .frd_almost_empty   ( frd_almost_empty ),
    .fwr_free           ( fwr_free ),
    .fwr_full           ( fwr_full ),
    .fwr_empty          ( fwr_empty ),
    .fwr_almost_empty   ( fwr_almost_empty ),
    .rd_halt            ( rd_halt ),
    .rd_error           ( rd_error ),
    .rd_busy            ( rd_busy ),
    .rd_cmd_done        ( rd_cmd_done ),
    .rd_trig_in         ( rd_trig_in ),
    .rd_trig_ack        ( rd_trig_ack ),
    .rd_trig_out        ( rd_trig_out ),
    .wr_halt            ( wr_halt ),
    .wr_error           ( wr_error ),
    .wr_busy            ( wr_busy ),
    .wr_cmd_done        ( wr_cmd_done ),
    .wr_trig_in         ( wr_trig_in ),
    .wr_trig_ack        ( wr_trig_ack ),
    .wr_trig_out        ( wr_trig_out )
);


// ** Command **
    
// Command to read/write engines
wire                    wr_cmd_almost_empty;
wire                    wr_cmd_push;
wire    [31:0]          wr_cmd_data;
wire                    rd_cmd_almost_empty;
wire                    rd_cmd_push;
wire    [31:0]          rd_cmd_data;

dlsc_dma_command #(
    .ADDR               ( CMD_ADDR ),
    .LEN                ( CMD_LEN )
) dlsc_dma_command_inst (
    .clk                ( clk ),
    .rst                ( rst_dma ),
    .apb_sel            ( cmd_apb_sel ),
    .apb_enable         ( apb_enable ),
    .apb_write          ( apb_write ),
    .apb_addr           ( apb_addr[3:2] ),
    .apb_wdata          ( apb_wdata ),
    .cmd_halt           ( cmd_halt ),
    .cmd_error          ( cmd_error ),
    .cmd_busy           ( cmd_busy ),
    .frd_free           ( frd_free ),
    .frd_full           ( frd_full ),
    .frd_empty          ( frd_empty ),
    .frd_almost_empty   ( frd_almost_empty ),
    .fwr_free           ( fwr_free ),
    .fwr_full           ( fwr_full ),
    .fwr_empty          ( fwr_empty ),
    .fwr_almost_empty   ( fwr_almost_empty ),
    .wr_cmd_almost_empty ( wr_cmd_almost_empty ),
    .wr_cmd_push        ( wr_cmd_push ),
    .wr_cmd_data        ( wr_cmd_data ),
    .rd_cmd_almost_empty ( rd_cmd_almost_empty ),
    .rd_cmd_push        ( rd_cmd_push ),
    .rd_cmd_data        ( rd_cmd_data ),
    .axi_ar_ready       ( cmd_ar_ready ),
    .axi_ar_valid       ( cmd_ar_valid ),
    .axi_ar_addr        ( cmd_ar_addr ),
    .axi_ar_len         ( cmd_ar_len ),
    .axi_r_ready        ( cmd_r_ready ),
    .axi_r_valid        ( cmd_r_valid ),
    .axi_r_last         ( cmd_r_last ),
    .axi_r_data         ( cmd_r_data ),
    .axi_r_resp         ( cmd_r_resp )
);


// ** Buffer **

// FIFO interface
wire                    fifo_wr_push;
wire    [DATA-1:0]      fifo_wr_data;
wire                    fifo_rd_pop;
wire    [DATA-1:0]      fifo_rd_data;
wire    [BUFA:0]        fifo_rd_count;
wire                    fifo_rd_empty;

dlsc_fifo #(
    .DATA               ( DATA ),
    .ADDR               ( BUFA )
) dlsc_fifo_inst (
    .clk                ( clk ),
    .rst                ( rst_dma ),
    .wr_push            ( fifo_wr_push ),
    .wr_data            ( fifo_wr_data ),
    .wr_full            (  ),
    .wr_almost_full     (  ),
    .wr_free            (  ),
    .rd_pop             ( fifo_rd_pop ),
    .rd_data            ( fifo_rd_data ),
    .rd_empty           ( fifo_rd_empty ),
    .rd_almost_empty    (  ),
    .rd_count           ( fifo_rd_count )
);


// ** Read **

dlsc_dma_read #(
    .DATA               ( DATA ),
    .ADDR               ( READ_ADDR ),
    .LEN                ( READ_LEN ),
    .LSB                ( LSB ),
    .BUFA               ( BUFA ),
    .MOT                ( READ_MOT ),
    .TRIG               ( TRIGGERS )
) dlsc_dma_read_inst (
    .clk                ( clk ),
    .rst                ( rst_dma ),
    .rd_halt            ( rd_halt ),
    .rd_error           ( rd_error ),
    .rd_busy            ( rd_busy ),
    .rd_cmd_done        ( rd_cmd_done ),
    .rd_trig_in         ( rd_trig_in ),
    .rd_trig_ack        ( rd_trig_ack ),
    .rd_trig_out        ( rd_trig_out ),
    .rd_cmd_almost_empty ( rd_cmd_almost_empty ),
    .rd_cmd_push        ( rd_cmd_push ),
    .rd_cmd_data        ( rd_cmd_data ),
    .fifo_wr_push       ( fifo_wr_push ),
    .fifo_wr_data       ( fifo_wr_data ),
    .fifo_rd_pop        ( fifo_rd_pop ),
    .axi_ar_ready       ( rd_ar_ready ),
    .axi_ar_valid       ( rd_ar_valid ),
    .axi_ar_addr        ( rd_ar_addr ),
    .axi_ar_len         ( rd_ar_len ),
    .axi_r_ready        ( rd_r_ready ),
    .axi_r_valid        ( rd_r_valid ),
    .axi_r_last         ( rd_r_last ),
    .axi_r_data         ( rd_r_data ),
    .axi_r_resp         ( rd_r_resp )
);


// ** Write **

dlsc_dma_write #(
    .DATA               ( DATA ),
    .ADDR               ( WRITE_ADDR ),
    .LEN                ( WRITE_LEN ),
    .LSB                ( LSB ),
    .BUFA               ( BUFA ),
    .MOT                ( WRITE_MOT ),
    .TRIG               ( TRIGGERS )
) dlsc_dma_write_inst (
    .clk                ( clk ),
    .rst                ( rst_dma ),
    .wr_halt            ( wr_halt ),
    .wr_error           ( wr_error ),
    .wr_busy            ( wr_busy ),
    .wr_cmd_done        ( wr_cmd_done ),
    .wr_trig_in         ( wr_trig_in ),
    .wr_trig_ack        ( wr_trig_ack ),
    .wr_trig_out        ( wr_trig_out ),
    .wr_cmd_almost_empty ( wr_cmd_almost_empty ),
    .wr_cmd_push        ( wr_cmd_push ),
    .wr_cmd_data        ( wr_cmd_data ),
    .fifo_rd_pop        ( fifo_rd_pop ),
    .fifo_rd_data       ( fifo_rd_data ),
    .fifo_rd_count      ( fifo_rd_count ),
    .fifo_rd_empty      ( fifo_rd_empty ),
    .axi_aw_ready       ( wr_aw_ready ),
    .axi_aw_valid       ( wr_aw_valid ),
    .axi_aw_addr        ( wr_aw_addr ),
    .axi_aw_len         ( wr_aw_len ),
    .axi_w_ready        ( wr_w_ready ),
    .axi_w_valid        ( wr_w_valid ),
    .axi_w_last         ( wr_w_last ),
    .axi_w_strb         ( wr_w_strb ),
    .axi_w_data         ( wr_w_data ),
    .axi_b_ready        ( wr_b_ready ),
    .axi_b_valid        ( wr_b_valid ),
    .axi_b_resp         ( wr_b_resp )
);


endmodule

