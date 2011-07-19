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
// Provides an asynchronous clock domain crossing for an APB bus.

module dlsc_apb_domaincross #(
    parameter DATA      = 32,
    parameter ADDR      = 32,
    // derived; don't touch
    parameter STRB      = (DATA/8)
) (
    // master domain
    // (connects to an APB master; is really an APB slave port)
    input   wire                    m_clk,
    input   wire                    m_rst,
    
    input   wire    [ADDR-1:0]      m_apb_addr,
    input   wire                    m_apb_sel,
    input   wire                    m_apb_enable,
    input   wire                    m_apb_write,
    input   wire    [DATA-1:0]      m_apb_wdata,
    input   wire    [STRB-1:0]      m_apb_strb,

    output  wire                    m_apb_ready,
    output  wire    [DATA-1:0]      m_apb_rdata,
    output  wire                    m_apb_slverr,

    // slave domain
    // (connects to an APB slave; is really an APB master port)
    input   wire                    s_clk,
    input   wire                    s_rst,
    
    output  wire    [ADDR-1:0]      s_apb_addr,
    output  wire                    s_apb_sel,
    output  wire                    s_apb_enable,
    output  wire                    s_apb_write,
    output  wire    [DATA-1:0]      s_apb_wdata,
    output  wire    [STRB-1:0]      s_apb_strb,

    input   wire                    s_apb_ready,
    input   wire    [DATA-1:0]      s_apb_rdata,
    input   wire                    s_apb_slverr
);

// master -> slave

wire            m_c_ready;
wire            m_c_valid;
wire            s_c_ready;
wire            s_c_valid;

dlsc_domaincross_rvh #(
    .DATA       ( ADDR+1+DATA+STRB )
) dlsc_domaincross_rvh_command (
    .in_clk     ( m_clk ),
    .in_rst     ( m_rst ),
    .in_ready   ( m_c_ready ),
    .in_valid   ( m_c_valid ),
    .in_data    ( {
        m_apb_addr,
        m_apb_write,
        m_apb_wdata,
        m_apb_strb } ),
    .out_clk    ( s_clk ),
    .out_rst    ( s_rst ),
    .out_ready  ( s_c_ready ),
    .out_valid  ( s_c_valid ),
    .out_data   ( {
        s_apb_addr,
        s_apb_write,
        s_apb_wdata,
        s_apb_strb } )
);


// slave -> master

wire            s_r_ready;
wire            s_r_valid;
wire            m_r_ready;
wire            m_r_valid;

dlsc_domaincross_rvh #(
    .DATA       ( DATA+1 ),
    .RESET      ( {(DATA+1){1'b0}} ),
    .RESET_ON_TRANSFER ( 1 )
) dlsc_domaincross_rvh_response (
    .in_clk     ( s_clk ),
    .in_rst     ( s_rst ),
    .in_ready   ( s_r_ready ),
    .in_valid   ( s_r_valid ),
    .in_data    ( {
        s_apb_rdata,
        s_apb_slverr } ),
    .out_clk    ( m_clk ),
    .out_rst    ( m_rst ),
    .out_ready  ( m_r_ready ),
    .out_valid  ( m_r_valid ),
    .out_data   ( {
        m_apb_rdata,
        m_apb_slverr } )
);


// master side handshaking

reg             m_launched;

assign          m_c_valid       = m_apb_sel && !m_launched;
assign          m_apb_ready     = m_r_valid;
assign          m_r_ready       = 1'b1;

always @(posedge m_clk) begin
    if(m_rst) begin
        m_launched      <= 1'b0;
    end else begin
        if(m_apb_ready) begin
            m_launched      <= 1'b0;
        end
        if(m_c_ready && m_c_valid) begin
            m_launched      <= 1'b1;
        end
    end
end


// slave side handshaking

assign          s_apb_sel       = s_c_valid && s_r_ready;
assign          s_c_ready       = s_apb_enable && s_apb_ready;
assign          s_r_valid       = s_c_ready;

always @(posedge s_clk) begin
    if(s_rst) begin
        s_apb_enable    <= 1'b0;
    end else begin
        if(s_apb_sel) begin
            s_apb_enable    <= 1'b1;
        end
        if(s_c_ready) begin
            s_apb_enable    <= 1'b0;
        end
    end
end


endmodule

