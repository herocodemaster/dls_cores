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
//
// This particular module is for just the AXI write channel (AW,W,B).

module dlsc_axi_rstcross_wr #(
    parameter AW_BITS           = 1,
    parameter W_BITS            = 1,
    parameter B_BITS            = 1,
    parameter W_PHONY           = {W_BITS{1'b0}},
    parameter B_PHONY           = {B_BITS{1'b0}},
    parameter LEN_BITS          = 4,
    parameter MAX_OUTSTANDING   = 15
) (
    // system
    input   wire                    clk,


    // ** master **

    input   wire                    m_rst,

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

`include "dlsc_clog2.vh"

localparam MAX_BITS     = `dlsc_clog2(MAX_OUTSTANDING+1);


// phony flags indicate when phony data is being supplied to make up for
// data that was lost in reset
reg m_phony = 1'b0;
reg s_phony = 1'b0;


// ** master **

reg  [MAX_BITS-1:0] m_w_cnt         = 0;
reg                 m_w_cnt_zero    = 1'b1;
reg  [MAX_BITS-1:0] m_b_cnt         = 0;
reg                 m_b_cnt_zero    = 1'b1;

// generate phony data if other side enters reset
always @(posedge clk) begin
    if(s_rst) begin
        m_phony         <= 1'b1;
    end else if(m_w_cnt_zero && m_b_cnt_zero) begin
        m_phony         <= 1'b0;
    end
end


// track AW/W/B beats
wire m_w_inc    = (m_aw_ready && m_aw_valid);
wire m_w_dec    = ( m_w_ready && m_w_valid && m_w_last);
wire m_b_inc    = m_w_dec;
wire m_b_dec    = ( m_b_ready && m_b_valid);

reg  [MAX_BITS-1:0] m_cnt           = 0;
reg                 m_cnt_max       = 1'b0;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(m_rst) begin
        m_w_cnt         <= 0;
        m_w_cnt_zero    <= 1'b1;
        m_b_cnt         <= 0;
        m_b_cnt_zero    <= 1'b1;
        m_cnt           <= 0;
        m_cnt_max       <= 1'b0;
    end else begin

        if( m_w_inc && !m_w_dec) begin
            m_w_cnt         <= m_w_cnt + 1;
            m_w_cnt_zero    <= 1'b0;
        end
        if(!m_w_inc &&  m_w_dec) begin
            m_w_cnt         <= m_w_cnt - 1;
            m_w_cnt_zero    <= (m_w_cnt == 1);
        end

        if( m_b_inc && !m_b_dec) begin
            m_b_cnt         <= m_b_cnt + 1;
            m_b_cnt_zero    <= 1'b0;
        end
        if(!m_b_inc &&  m_b_dec) begin
            m_b_cnt         <= m_b_cnt - 1;
            m_b_cnt_zero    <= (m_b_cnt == 1);
        end

        if( m_w_inc && !m_b_dec) begin
            m_cnt           <= m_cnt + 1;
            m_cnt_max       <= (m_cnt == (MAX_OUTSTANDING-1));
        end
        if(!m_w_inc &&  m_b_dec) begin
            m_cnt           <= m_cnt - 1;
            m_cnt_max       <= 1'b0;
        end

    end
end
/* verilator lint_on WIDTH */


assign m_aw_ready   = m_phony ? ( 1'b0 )                : ( !s_phony && s_aw_ready && !m_cnt_max );

assign m_w_ready    = m_phony ? ( !m_w_cnt_zero )       : ( !s_phony && s_w_ready && !m_w_cnt_zero );

assign m_b_valid    = m_phony ? ( !m_b_cnt_zero )       : ( !s_phony && s_b_valid );
assign m_b          = m_phony ? ( B_PHONY )             : ( s_b );


// ** slave **

wire                s_empty;

reg  [MAX_BITS-1:0] s_b_cnt         = 0;
reg                 s_b_cnt_zero    = 1'b1;

// generate phony data if other side enters reset
always @(posedge clk) begin
    if(m_rst) begin
        s_phony         <= 1'b1;
    end else if(s_empty && s_b_cnt_zero) begin
        s_phony         <= 1'b0;
    end
end


// track W beats
reg  [LEN_BITS-1:0] s_w_cnt;

always @(posedge clk) begin
    if(s_rst) begin
        s_w_cnt     <= 0;
    end else if(s_w_ready && s_w_valid) begin
        s_w_cnt     <= s_w_last ? 0 : (s_w_cnt + 1);
    end
end


// track command lengths (in order to produce correct w_last)
wire [LEN_BITS-1:0] s_w_len;

wire s_push_en  = s_aw_ready && s_aw_valid;
wire s_pop_en   = s_w_ready && s_w_valid && s_w_last;

dlsc_fifo #(
    .DATA           ( LEN_BITS ),
    .DEPTH          ( MAX_OUTSTANDING ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo_inst (
    .clk            ( clk ),
    .rst            ( s_rst ),
    .wr_push        ( s_push_en && !(s_pop_en && s_empty) ),    // don't push if popping when empty
    .wr_data        ( s_aw_len ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( s_pop_en && !s_empty ),                   // don't actually pop when empty
    .rd_data        ( s_w_len ),
    .rd_empty       ( s_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);


// track B beats
wire s_b_inc    = ( s_w_ready && s_w_valid && s_w_last );
wire s_b_dec    = ( s_b_ready && s_b_valid );

always @(posedge clk) begin
    if(s_rst) begin
        s_b_cnt         <= 0;
        s_b_cnt_zero    <= 1'b1;
    end else begin

        if( s_b_inc && !s_b_dec ) begin
            s_b_cnt         <= s_b_cnt + 1;
            s_b_cnt_zero    <= 1'b0;
        end
        if(!s_b_inc &&  s_b_dec ) begin
            s_b_cnt         <= s_b_cnt - 1;
            s_b_cnt_zero    <= (s_b_cnt == 1);
        end
    
    end
end


assign s_aw_valid   = s_phony ? ( 1'b0 )                : ( !m_phony && m_aw_valid && !m_cnt_max );
assign s_aw_len     = m_aw_len;
assign s_aw         = m_aw;

assign s_w_valid    = s_phony ? ( !s_empty )            : ( !m_phony && m_w_valid && !m_w_cnt_zero );
assign s_w_last     = s_phony ? ( s_w_cnt == s_w_len )  : ( m_w_last );
assign s_w          = s_phony ? ( W_PHONY )             : ( m_w );

assign s_b_ready    = s_phony ? ( !s_b_cnt_zero )       : ( !m_phony && m_b_ready );


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(!m_rst) begin
        if(m_w_inc && !m_w_dec && &m_w_cnt) begin
            `dlsc_error("m_w_cnt overflow");
        end
        if(!m_w_inc && m_w_dec && m_w_cnt == 0) begin
            `dlsc_error("m_w_cnt underflow");
        end
        if(m_b_inc && !m_b_dec && &m_b_cnt) begin
            `dlsc_error("m_b_cnt overflow");
        end
        if(!m_b_inc && m_b_dec && m_b_cnt == 0) begin
            `dlsc_error("m_b_cnt underflow");
        end
        if(m_w_inc && !m_b_dec && &m_cnt) begin
            `dlsc_error("m_cnt overflow");
        end
        if(!m_w_inc && m_b_dec && m_cnt == 0) begin
            `dlsc_error("m_cnt underflow");
        end
    end
    if(!s_rst) begin
        if(s_b_inc && !s_b_dec && &s_b_cnt) begin
            `dlsc_error("s_b_cnt overflow");
        end
        if(!s_b_inc && s_b_dec && s_b_cnt == 0) begin
            `dlsc_error("s_b_cnt underflow");
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

