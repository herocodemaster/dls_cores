
module dlsc_axi_rstcross_test #(
    // common
    parameter DATA              = 32,
    parameter ADDR              = 32,
    parameter LEN               = 4,
    parameter RESP              = 2,
    parameter MAX_OUTSTANDING   = 15
) (
    // system
    input   wire                    clk,


    // ** master **

    input   wire                    m_rst,

    // read command
    output  wire                    m_ar_ready,
    input   wire                    m_ar_valid,
    input   wire    [ADDR-1:0]      m_ar_addr,
    input   wire    [LEN-1:0]       m_ar_len,

    // read data/response
    input   wire                    m_r_ready,
    output  wire                    m_r_valid,
    output  wire                    m_r_last,
    output  wire    [DATA-1:0]      m_r_data,
    output  wire    [RESP-1:0]      m_r_resp,

    // write command
    output  wire                    m_aw_ready,
    input   wire                    m_aw_valid,
    input   wire    [ADDR-1:0]      m_aw_addr,
    input   wire    [LEN-1:0]       m_aw_len,

    // write data
    output  wire                    m_w_ready,
    input   wire                    m_w_valid,
    input   wire                    m_w_last,
    input   wire    [DATA-1:0]      m_w_data,
    input   wire    [(DATA/8)-1:0]  m_w_strb,

    // write response
    input   wire                    m_b_ready,
    output  wire                    m_b_valid,
    output  wire    [RESP-1:0]      m_b_resp,


    // ** slave **

    input   wire                    s_rst,

    // read command
    input   wire                    s_ar_ready,
    output  wire                    s_ar_valid,
    output  wire    [ADDR-1:0]      s_ar_addr,
    output  wire    [LEN-1:0]       s_ar_len,

    // read data/response
    output  wire                    s_r_ready,
    input   wire                    s_r_valid,
    input   wire                    s_r_last,
    input   wire    [DATA-1:0]      s_r_data,
    input   wire    [RESP-1:0]      s_r_resp,

    // write command
    input   wire                    s_aw_ready,
    output  wire                    s_aw_valid,
    output  wire    [ADDR-1:0]      s_aw_addr,
    output  wire    [LEN-1:0]       s_aw_len,

    // write data
    input   wire                    s_w_ready,
    output  wire                    s_w_valid,
    output  wire                    s_w_last,
    output  wire    [DATA-1:0]      s_w_data,
    output  wire    [(DATA/8)-1:0]  s_w_strb,

    // write response
    output  wire                    s_b_ready,
    input   wire                    s_b_valid,
    input   wire    [RESP-1:0]      s_b_resp
);

// read
localparam AR_BITS  = ADDR;
localparam R_BITS   = DATA + RESP;
localparam R_PHONY  = { {DATA{1'b0}}, 2'b10 };  // SLVERR
// write
localparam AW_BITS  = ADDR;
localparam W_BITS   = DATA + (DATA/8);
localparam B_BITS   = RESP;
localparam W_PHONY  = {W_BITS{1'b0}};
localparam B_PHONY  = 2'b10;                    // SLVERR

dlsc_axi_rstcross #(
    .AR_BITS            ( AR_BITS ),
    .R_BITS             ( R_BITS ),
    .R_PHONY            ( R_PHONY ),
    .AW_BITS            ( AW_BITS ),
    .W_BITS             ( W_BITS ),
    .B_BITS             ( B_BITS ),
    .W_PHONY            ( W_PHONY ),
    .B_PHONY            ( B_PHONY ),
    .LEN_BITS           ( LEN ),
    .MAX_OUTSTANDING    ( MAX_OUTSTANDING )
) dlsc_axi_rstcross_inst (
    // system
    .clk                ( clk ),

    // ** master **
    .m_rst              ( m_rst ),
    // read command
    .m_ar_ready         ( m_ar_ready ),
    .m_ar_valid         ( m_ar_valid ),
    .m_ar_len           ( m_ar_len ),
    .m_ar               ( { m_ar_addr } ),
    // read data/response
    .m_r_ready          ( m_r_ready ),
    .m_r_valid          ( m_r_valid ),
    .m_r_last           ( m_r_last ),
    .m_r                ( { m_r_data, m_r_resp } ),
    // write command
    .m_aw_ready         ( m_aw_ready ),
    .m_aw_valid         ( m_aw_valid ),
    .m_aw_len           ( m_aw_len ),
    .m_aw               ( { m_aw_addr } ),
    // write data
    .m_w_ready          ( m_w_ready ),
    .m_w_valid          ( m_w_valid ),
    .m_w_last           ( m_w_last ),
    .m_w                ( { m_w_data, m_w_strb } ),
    // write response
    .m_b_ready          ( m_b_ready ),
    .m_b_valid          ( m_b_valid ),
    .m_b                ( { m_b_resp } ),

    // ** slave **
    .s_rst              ( s_rst ),
    // read command
    .s_ar_ready         ( s_ar_ready ),
    .s_ar_valid         ( s_ar_valid ),
    .s_ar_len           ( s_ar_len ),
    .s_ar               ( { s_ar_addr } ),
    // read data/response
    .s_r_ready          ( s_r_ready ),
    .s_r_valid          ( s_r_valid ),
    .s_r_last           ( s_r_last ),
    .s_r                ( { s_r_data, s_r_resp } ),
    // write command
    .s_aw_ready         ( s_aw_ready ),
    .s_aw_valid         ( s_aw_valid ),
    .s_aw_len           ( s_aw_len ),
    .s_aw               ( { s_aw_addr } ),
    // write data
    .s_w_ready          ( s_w_ready ),
    .s_w_valid          ( s_w_valid ),
    .s_w_last           ( s_w_last ),
    .s_w                ( { s_w_data, s_w_strb } ),
    // write response
    .s_b_ready          ( s_b_ready ),
    .s_b_valid          ( s_b_valid ),
    .s_b                ( { s_b_resp } )
);


endmodule

