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
    // read
    parameter AR_BITS           = 1,
    parameter R_BITS            = 1,
    parameter R_PHONY           = {R_BITS{1'b0}},
    // write
    parameter AW_BITS           = 1,
    parameter W_BITS            = 1,
    parameter B_BITS            = 1,
    parameter W_PHONY           = {W_BITS{1'b0}},
    parameter B_PHONY           = {B_BITS{1'b0}},
    // common
    parameter LEN_BITS          = 4,
    parameter MAX_OUTSTANDING   = 15
) (
    // system
    input   wire                    clk,


    // ** master **

    input   wire                    m_rst,

    // read command
    output  wire                    m_ar_ready,
    input   wire                    m_ar_valid,
    input   wire    [LEN_BITS-1:0]  m_ar_len,
    input   wire    [AR_BITS-1:0]   m_ar,

    // read data/response
    input   wire                    m_r_ready,
    output  wire                    m_r_valid,
    output  wire                    m_r_last,
    output  wire    [R_BITS-1:0]    m_r,

    // write command
    output  wire                    m_aw_ready,
    input   wire                    m_aw_valid,
    input   wire    [LEN_BITS-1:0]  m_aw_len,
    input   wire    [AW_BITS-1:0]   m_aw,

    // write data
    output  wire                    m_w_ready,
    input   wire                    m_w_valid,
    input   wire                    m_w_last,
    input   wire    [W_BITS-1:0]    m_w,

    // write response
    input   wire                    m_b_ready,
    output  wire                    m_b_valid,
    output  wire    [B_BITS-1:0]    m_b,


    // ** slave **

    input   wire                    s_rst,

    // read command
    input   wire                    s_ar_ready,
    output  wire                    s_ar_valid,
    output  wire    [LEN_BITS-1:0]  s_ar_len,
    output  wire    [AR_BITS-1:0]   s_ar,

    // read data/response
    output  wire                    s_r_ready,
    input   wire                    s_r_valid,
    input   wire                    s_r_last,
    input   wire    [R_BITS-1:0]    s_r,

    // write command
    input   wire                    s_aw_ready,
    output  wire                    s_aw_valid,
    output  wire    [LEN_BITS-1:0]  s_aw_len,
    output  wire    [AW_BITS-1:0]   s_aw,

    // write data
    input   wire                    s_w_ready,
    output  wire                    s_w_valid,
    output  wire                    s_w_last,
    output  wire    [W_BITS-1:0]    s_w,

    // write response
    output  wire                    s_b_ready,
    input   wire                    s_b_valid,
    input   wire    [B_BITS-1:0]    s_b
);

// ** read **

dlsc_axi_rstcross_rd #(
    .AR_BITS            ( AR_BITS ),
    .R_BITS             ( R_BITS ),
    .R_PHONY            ( R_PHONY ),
    .LEN_BITS           ( LEN_BITS ),
    .MAX_OUTSTANDING    ( MAX_OUTSTANDING )
) dlsc_axi_rstcross_rd_inst (
    // system
    .clk                ( clk ),
    // ** master **
    .m_rst              ( m_rst ),
    // read command
    .m_ar_ready         ( m_ar_ready ),
    .m_ar_valid         ( m_ar_valid ),
    .m_ar_len           ( m_ar_len ),
    .m_ar               ( m_ar ),
    // read data/response
    .m_r_ready          ( m_r_ready ),
    .m_r_valid          ( m_r_valid ),
    .m_r_last           ( m_r_last ),
    .m_r                ( m_r ),
    // ** slave **
    .s_rst              ( s_rst ),
    // read command
    .s_ar_ready         ( s_ar_ready ),
    .s_ar_valid         ( s_ar_valid ),
    .s_ar_len           ( s_ar_len ),
    .s_ar               ( s_ar ),
    // read data/response
    .s_r_ready          ( s_r_ready ),
    .s_r_valid          ( s_r_valid ),
    .s_r_last           ( s_r_last ),
    .s_r                ( s_r )
);


// ** write **

dlsc_axi_rstcross_wr #(
    .AW_BITS            ( AW_BITS ),
    .W_BITS             ( W_BITS ),
    .B_BITS             ( B_BITS ),
    .W_PHONY            ( W_PHONY ),
    .B_PHONY            ( B_PHONY ),
    .LEN_BITS           ( LEN_BITS ),
    .MAX_OUTSTANDING    ( MAX_OUTSTANDING )
) dlsc_axi_rstcross_wr_inst (
    // system
    .clk                ( clk ),
    // ** master **
    .m_rst              ( m_rst ),
    // write command
    .m_aw_ready         ( m_aw_ready ),
    .m_aw_valid         ( m_aw_valid ),
    .m_aw_len           ( m_aw_len ),
    .m_aw               ( m_aw ),
    // write data
    .m_w_ready          ( m_w_ready ),
    .m_w_valid          ( m_w_valid ),
    .m_w_last           ( m_w_last ),
    .m_w                ( m_w ),
    // write response
    .m_b_ready          ( m_b_ready ),
    .m_b_valid          ( m_b_valid ),
    .m_b                ( m_b ),
    // ** slave **
    .s_rst              ( s_rst ),
    // write command
    .s_aw_ready         ( s_aw_ready ),
    .s_aw_valid         ( s_aw_valid ),
    .s_aw_len           ( s_aw_len ),
    .s_aw               ( s_aw ),
    // write data
    .s_w_ready          ( s_w_ready ),
    .s_w_valid          ( s_w_valid ),
    .s_w_last           ( s_w_last ),
    .s_w                ( s_w ),
    // write response
    .s_b_ready          ( s_b_ready ),
    .s_b_valid          ( s_b_valid ),
    .s_b                ( s_b )
);


endmodule

