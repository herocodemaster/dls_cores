
module dlsc_axi_rstcross_test #(
    parameter MASTER_RESET      = 1,    // support safe m_rst
    parameter SLAVE_RESET       = 1,    // support safe s_rst
    parameter REGISTER          = 0,
    parameter DATA              = 32,
    parameter ADDR              = 32,
    parameter LEN               = 4,
    parameter MOT               = 16,
    // derived; don't touch
    parameter STRB              = (DATA/8)
) (
    // system
    input   wire                clk,

    // ** master **

    input   wire                m_rst,

    // read command
    output  wire                m_ar_ready,
    input   wire                m_ar_valid,
    input   wire    [ADDR-1:0]  m_ar_addr,
    input   wire    [LEN-1:0]   m_ar_len,

    // read data/response
    input   wire                m_r_ready,
    output  wire                m_r_valid,
    output  wire                m_r_last,
    output  wire    [DATA-1:0]  m_r_data,
    output  wire    [RESP-1:0]  m_r_resp,

    // write command
    output  wire                m_aw_ready,
    input   wire                m_aw_valid,
    input   wire    [ADDR-1:0]  m_aw_addr,
    input   wire    [LEN-1:0]   m_aw_len,

    // write data
    output  wire                m_w_ready,
    input   wire                m_w_valid,
    input   wire                m_w_last,
    input   wire    [STRB-1:0]  m_w_strb,
    input   wire    [DATA-1:0]  m_w_data,

    // write response
    input   wire                m_b_ready,
    output  wire                m_b_valid,
    output  wire    [RESP-1:0]  m_b_resp,

    // ** slave **

    input   wire                s_rst,

    // read command
    input   wire                s_ar_ready,
    output  wire                s_ar_valid,
    output  wire    [ADDR-1:0]  s_ar_addr,
    output  wire    [LEN-1:0]   s_ar_len,

    // read data/response
    output  wire                s_r_ready,
    input   wire                s_r_valid,
    input   wire                s_r_last,
    input   wire    [DATA-1:0]  s_r_data,
    input   wire    [RESP-1:0]  s_r_resp,

    // write command
    input   wire                s_aw_ready,
    output  wire                s_aw_valid,
    output  wire    [ADDR-1:0]  s_aw_addr,
    output  wire    [LEN-1:0]   s_aw_len,

    // write data
    input   wire                s_w_ready,
    output  wire                s_w_valid,
    output  wire                s_w_last,
    output  wire    [STRB-1:0]  s_w_strb,
    output  wire    [DATA-1:0]  s_w_data,

    // write response
    output  wire                s_b_ready,
    input   wire                s_b_valid,
    input   wire    [RESP-1:0]  s_b_resp
);

dlsc_axi_rstcross #(
    .MASTER_RESET       ( MASTER_RESET ),
    .SLAVE_RESET        ( SLAVE_RESET ),
    .REGISTER           ( REGISTER ),
    .DATA               ( DATA ),
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MOT                ( MOT )
) dlsc_axi_rstcross_inst (
    // system
    .clk                ( clk ),

    // ** master **
    .m_rst              ( m_rst ),
    // read command
    .m_ar_ready         ( m_ar_ready ),
    .m_ar_valid         ( m_ar_valid ),
    .m_ar_addr          ( m_ar_addr ),
    .m_ar_len           ( m_ar_len ),
    // read data/response
    .m_r_ready          ( m_r_ready ),
    .m_r_valid          ( m_r_valid ),
    .m_r_last           ( m_r_last ),
    .m_r_data           ( m_r_data ),
    .m_r_resp           ( m_r_resp ),
    // write command
    .m_aw_ready         ( m_aw_ready ),
    .m_aw_valid         ( m_aw_valid ),
    .m_aw_addr          ( m_aw_addr ),
    .m_aw_len           ( m_aw_len ),
    // write data
    .m_w_ready          ( m_w_ready ),
    .m_w_valid          ( m_w_valid ),
    .m_w_last           ( m_w_last ),
    .m_w_strb           ( m_w_strb ),
    .m_w_data           ( m_w_data ),
    // write response
    .m_b_ready          ( m_b_ready ),
    .m_b_valid          ( m_b_valid ),
    .m_b_resp           ( m_b_resp ),

    // ** slave **
    .s_rst              ( s_rst ),
    // read command
    .s_ar_ready         ( s_ar_ready ),
    .s_ar_valid         ( s_ar_valid ),
    .s_ar_addr          ( s_ar_addr ),
    .s_ar_len           ( s_ar_len ),
    // read data/response
    .s_r_ready          ( s_r_ready ),
    .s_r_valid          ( s_r_valid ),
    .s_r_last           ( s_r_last ),
    .s_r_data           ( s_r_data ),
    .s_r_resp           ( s_r_resp ),
    // write command
    .s_aw_ready         ( s_aw_ready ),
    .s_aw_valid         ( s_aw_valid ),
    .s_aw_addr          ( s_aw_addr ),
    .s_aw_len           ( s_aw_len ),
    // write data
    .s_w_ready          ( s_w_ready ),
    .s_w_valid          ( s_w_valid ),
    .s_w_last           ( s_w_last ),
    .s_w_strb           ( s_w_strb ),
    .s_w_data           ( s_w_data ),
    // write response
    .s_b_ready          ( s_b_ready ),
    .s_b_valid          ( s_b_valid ),
    .s_b_resp           ( s_b_resp )
);


endmodule

