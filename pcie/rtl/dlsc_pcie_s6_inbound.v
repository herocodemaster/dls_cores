
module dlsc_pcie_s6_inbound (
    // pcie common interface
    input   wire            clk,        // user_clk_out
    input   wire            rst,        // user_reset_out

    // pcie receive interface
    output  reg             rx_ready,   // m_axis_rx_tready
    input   wire            rx_valid,   // m_axis_rx_tvalid
    input   wire            rx_last,    // m_axis_rx_tlast

    input   wire    [31:0]  rx_data,    // m_axis_rx_tdata[31:0]
    input   wire    [6:0]   rx_bar,     // m_axis_tx_tuser[9:2]
    input   wire            rx_err,     // m_axis_tx_tuser[1]
    
    output  reg             rx_np_ok,   // rx_np_ok

    // read requests - command
    input   wire            rd_ready,
    output  reg             rd_valid,
    output  wire    [9:0]   rd_length,
    output  reg     [7:0]   rd_tag,
    output  wire    [3:0]   rd_be_last,
    output  wire    [3:0]   rd_be_first,
    output  wire    [63:2]  rd_addr,
    output  wire    [6:0]   rd_bar,

    // write requests - command
    input   wire            wr_ready,
    output  reg             wr_valid,
    output  wire    [9:0]   wr_length,
    output  wire    [3:0]   wr_be_last,
    output  wire    [3:0]   wr_be_first,
    output  wire    [63:2]  wr_addr,
    output  wire    [6:0]   wr_bar,

    // write requests - payload
    input   wire            wrp_ready,
    output  reg             wrp_valid,
    output  wire            wrp_last,
    output  wire    [31:0]  wrp_data,

    // completions - command
    input   wire            cpl_ready,
    output  reg             cpl_valid,
    output  reg     [2:0]   cpl_status,
    output  reg             cpl_bcm,
    output  reg     [11:0]  cpl_bytes,
    output  reg     [7:0]   cpl_tag,

    // completions - payload
    input   wire            cplp_ready,
    output  reg             cplp_valid,
    output  wire            cplp_last,
    output  wire    [31:0]  cplp_data,
);

reg     [9:0]   cmd_length;
reg     [3:0]   cmd_be_last;
reg     [3:0]   cmd_be_first;
reg     [63:2]  cmd_addr;
reg     [6:0]   cmd_bar;

assign rd_length    = cmd_length;
assign rd_be_last   = cmd_be_last;
assign rd_be_first  = cmd_be_first;
assign rd_addr      = cmd_addr;
assign rd_bar       = cmd_bar;

assign wr_length    = cmd_length;
assign wr_be_last   = cmd_be_last;
assign wr_be_first  = cmd_be_first;
assign wr_addr      = cmd_addr;
assign wr_bar       = cmd_bar;

reg             pl_last;
reg     [31:0]  pl_data;

assign wrp_last     = pl_last;
assign wrp_data     = pl_data;

assign cplp_last    = pl_last;
assign cplp_data    = pl_data;

endmodule

