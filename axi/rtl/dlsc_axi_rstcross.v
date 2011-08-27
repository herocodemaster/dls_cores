// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// Provides a safe way to connect an AXI master to a slave with a different
// reset. Generates phony traffic to complete transactions that would have
// otherwise been lost to reset (thus preventing a bus stall).

module dlsc_axi_rstcross #(
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
    output  wire    [1:0]       m_r_resp,

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
    output  wire    [1:0]       m_b_resp,

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
    input   wire    [1:0]       s_r_resp,

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
    input   wire    [1:0]       s_b_resp
);

// ** read **

localparam AR_BITS  = ADDR;
localparam R_BITS   = DATA + 2;
localparam R_PHONY  = { {DATA{1'b0}}, 2'b10 };  // SLVERR

dlsc_axi_rstcross_rd #(
    .AR_BITS            ( AR_BITS ),
    .R_BITS             ( R_BITS ),
    .R_PHONY            ( R_PHONY ),
    .LEN_BITS           ( LEN ),
    .MAX_OUTSTANDING    ( MOT )
) dlsc_axi_rstcross_rd_inst (
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
    .s_r                ( { s_r_data, s_r_resp } )
);


// ** write **

dlsc_axi_rstcross_wr #(
    .MASTER_RESET       ( MASTER_RESET ),
    .SLAVE_RESET        ( SLAVE_RESET ),
    .REGISTER           ( REGISTER ),
    .DATA               ( DATA ),
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MOT                ( MOT )
) dlsc_axi_rstcross_wr_inst (
    // system
    .clk                ( clk ),
    // ** master **
    .m_rst              ( m_rst ),
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

