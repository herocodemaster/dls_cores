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
    parameter DATA          = 32,
    parameter ADDR          = 32,
    parameter RESET_SLVERR  = 1,    // generate slverr response if slave is in reset
    // derived; don't touch
    parameter STRB          = (DATA/8)
) (
    // master domain
    // (connects to an APB master; is really an APB slave port)
    input   wire                    in_clk,
    input   wire                    in_rst,
    
    input   wire    [ADDR-1:0]      in_addr,
    input   wire                    in_sel,
    input   wire                    in_enable,
    input   wire                    in_write,
    input   wire    [DATA-1:0]      in_wdata,
    input   wire    [STRB-1:0]      in_strb,

    output  reg                     in_ready,
    output  wire    [DATA-1:0]      in_rdata,
    output  wire                    in_slverr,

    // slave domain
    // (connects to an APB slave; is really an APB master port)
    input   wire                    out_clk,
    input   wire                    out_rst,
    
    output  wire    [ADDR-1:0]      out_addr,
    output  reg                     out_sel,
    output  reg                     out_enable,
    output  wire                    out_write,
    output  wire    [DATA-1:0]      out_wdata,
    output  wire    [STRB-1:0]      out_strb,

    input   wire                    out_ready,
    input   wire    [DATA-1:0]      out_rdata,
    input   wire                    out_slverr
);

`include "dlsc_synthesis.vh"

localparam CMD = ADDR+DATA+STRB;

`DLSC_KEEP_REG reg m_req;
`DLSC_KEEP_REG reg s_ack;


// ** master domain **

localparam  ST_CMD      = 0,
            ST_RSP      = 1,
            ST_RST      = 2;

reg  [1:0]      st;
reg  [1:0]      next_st;

wire            m_s_ack;    // ack from slave domain
wire            m_s_rst;    // reset from slave domain

always @* begin

    next_st     = st;

    if(st == ST_CMD && in_sel && !in_ready) begin
        if(m_s_rst) begin
            next_st     = ST_RST;
        end else if(!m_s_ack) begin
            next_st     = ST_RSP;
        end
    end

    if(st == ST_RSP) begin
        if(m_s_rst) begin
            next_st     = ST_RST;
        end else if(m_s_ack) begin
            next_st     = ST_CMD;
        end
    end

    if(st == ST_RST) begin
        next_st     = ST_CMD;
    end

end

reg             in_slverr_force;

always @(posedge in_clk) begin
    if(in_rst) begin
        st              <= ST_CMD;
        m_req           <= 1'b0;
        in_slverr_force <= 1'b0;
        in_ready        <= 1'b0;
    end else begin
        st              <= next_st;
        m_req           <= (next_st == ST_RSP);
        in_slverr_force <= (next_st == ST_RST) && RESET_SLVERR;
        in_ready        <= (next_st == ST_RST) || (st == ST_RSP && m_s_ack);
    end
end

wire            in_slverr_pre;
assign          in_slverr       = in_slverr_pre || in_slverr_force;


// ** sync **

// handshake

wire            s_m_req;

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_req (
    .in         ( m_req ),
    .clk        ( out_clk ),
    .rst        ( out_rst ),
    .out        ( s_m_req )
);

dlsc_syncflop #(
    .DEPTH      ( 3 ),      // one more than reset path
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_ack (
    .in         ( s_ack ),
    .clk        ( in_clk ),
    .rst        ( in_rst || m_s_rst ),
    .out        ( m_s_ack )
);

dlsc_syncflop #(
    .DEPTH      ( 2 ),      // one less than ack path
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_rst (
    .in         ( out_rst ),
    .clk        ( in_clk ),
    .rst        ( in_rst ),
    .out        ( m_s_rst )
);

// master -> slave

wire            m_cmd_en        = in_sel && !in_enable && !m_s_rst;

wire            s_cmd_en        = s_m_req && !out_sel && !s_ack;

wire [CMD:0]    in_cmd          = { in_addr,
                                    in_write,
                                    in_wdata,
                                    in_strb };

wire [CMD:0]    out_cmd;
assign        { out_addr,
                out_write,
                out_wdata,
                out_strb }      = out_cmd;

dlsc_domaincross_slice dlsc_domaincross_slice_cmd [CMD:0] (
    .in_clk     ( in_clk ),
    .in_rst     ( 1'b0 ),
    .in_en      ( m_cmd_en ),
    .in_data    ( in_cmd ),
    .out_clk    ( out_clk ),
    .out_rst    ( 1'b0 ),
    .out_en     ( s_cmd_en ),
    .out_data   ( out_cmd )
);

// slave -> master

wire            s_rsp_en        = (out_enable && out_ready);

wire            m_rsp_rst       = (in_enable && in_ready) || in_rst;
wire            m_rsp_en        = m_s_ack && !m_s_rst && (st == ST_RSP);

wire [DATA:0]   out_rsp         = { out_rdata,
                                    out_slverr };

wire [DATA:0]   in_rsp;
assign        { in_rdata,
                in_slverr_pre } = in_rsp;

dlsc_domaincross_slice dlsc_domaincross_slice_rsp [DATA:0] (
    .in_clk     ( out_clk ),
    .in_rst     ( 1'b0 ),
    .in_en      ( s_rsp_en ),
    .in_data    ( out_rsp ),
    .out_clk    ( in_clk ),
    .out_rst    ( m_rsp_rst ),
    .out_en     ( m_rsp_en ),
    .out_data   ( in_rsp )
);


// ** slave domain **

always @(posedge out_clk) begin
    if(out_rst) begin
        s_ack       <= 1'b1;
        out_sel     <= 1'b0;
        out_enable  <= 1'b0;
    end else begin
        if(!s_m_req) begin
            s_ack       <= 1'b0;
        end
        if(s_cmd_en) begin
            out_sel     <= 1'b1;
        end
        if(out_sel) begin
            out_enable  <= 1'b1;
        end
        if(s_rsp_en) begin
            out_sel     <= 1'b0;
            out_enable  <= 1'b0;
            s_ack       <= 1'b1;
        end
    end
end


// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(negedge out_rst) begin
    // out_rst deasserted
    // check that it was long enough for master domain to respond
    if( !(m_s_rst && m_s_ack && !m_req) ) begin
        `dlsc_error("out_rst pulse was too short");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

