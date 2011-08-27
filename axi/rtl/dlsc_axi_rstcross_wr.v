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

    // write command
    output  reg                 m_aw_ready,
    input   wire                m_aw_valid,
    input   wire    [ADDR-1:0]  m_aw_addr,
    input   wire    [LEN-1:0]   m_aw_len,

    // write data
    output  reg                 m_w_ready,
    input   wire                m_w_valid,
    input   wire                m_w_last,
    input   wire    [STRB-1:0]  m_w_strb,
    input   wire    [DATA-1:0]  m_w_data,

    // write response
    input   wire                m_b_ready,
    output  reg                 m_b_valid,
    output  reg     [1:0]       m_b_resp,

    // ** slave **

    input   wire                s_rst,

    // write command
    input   wire                s_aw_ready,
    output  reg                 s_aw_valid,
    output  reg     [ADDR-1:0]  s_aw_addr,
    output  reg     [LEN-1:0]   s_aw_len,

    // write data
    input   wire                s_w_ready,
    output  reg                 s_w_valid,
    output  reg                 s_w_last,
    output  reg     [STRB-1:0]  s_w_strb,
    output  reg     [DATA-1:0]  s_w_data,

    // write response
    output  reg                 s_b_ready,
    input   wire                s_b_valid,
    input   wire    [1:0]       s_b_resp
);

`include "dlsc_clog2.vh"

localparam  MOTB            = `dlsc_clog2(MOT+1);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;


// phony flags indicate when phony data is being supplied to make up for
// data that was lost in reset
reg             m_phony;
reg             s_phony;


// ** master tracking **

reg             m_w_cnt_zero;
reg             m_b_cnt_zero;
reg             m_cnt_max;

generate
if(SLAVE_RESET) begin:GEN_MPHONY

    reg  [MOTB-1:0] m_w_cnt;
    reg  [MOTB-1:0] m_b_cnt;
    reg  [MOTB-1:0] m_cnt;

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
                m_cnt_max       <= (m_cnt == (MOT-1));
            end
            if(!m_w_inc &&  m_b_dec) begin
                m_cnt           <= m_cnt - 1;
                m_cnt_max       <= 1'b0;
            end

        end
    end
    /* verilator lint_on WIDTH */
    
    // simulation checks
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
    end
    `include "dlsc_sim_bot.vh"
    `endif

end else begin:GEN_NO_MPHONY

    always @(posedge clk) begin
        m_phony         <= 1'b0;
        m_w_cnt_zero    <= 1'b0;
        m_b_cnt_zero    <= 1'b0;
        m_cnt_max       <= 1'b0;
    end

end
endgenerate


// ** slave tracking **

wire            s_empty;
wire            s_last;

reg             s_b_cnt_zero;

generate
if(MASTER_RESET) begin:GEN_SPHONY

    // generate phony data if other side enters reset
    always @(posedge clk) begin
        if(m_rst) begin
            s_phony         <= 1'b1;
        end else if(s_empty && s_b_cnt_zero) begin
            s_phony         <= 1'b0;
        end
    end

    // track W beats
    reg  [LEN-1:0]  s_w_cnt;

    always @(posedge clk) begin
        if(s_rst) begin
            s_w_cnt     <= 0;
        end else if(s_w_ready && s_w_valid) begin
            s_w_cnt     <= s_w_last ? 0 : (s_w_cnt + 1);
        end
    end

    // track command lengths (in order to produce correct w_last)
    wire [LEN-1:0]  s_w_len;

    wire            s_push_en       = s_aw_ready && s_aw_valid;
    wire            s_pop_en        = s_w_ready && s_w_valid && s_w_last;

    dlsc_fifo #(
        .DATA           ( LEN ),
        .DEPTH          ( MOT ),
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

    assign          s_last          = (s_w_cnt == s_w_len);

    // track B beats
    reg  [MOTB-1:0] s_b_cnt;

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

    // simulation checks
    `ifdef DLSC_SIMULATION
    `include "dlsc_sim_top.vh"
    always @(posedge clk) begin
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

end else begin:GEN_NO_SPHONY

    always @(posedge clk) begin
        s_phony         <= 1'b0;
        s_b_cnt_zero    <= 1'b0;
    end

    assign          s_empty     = 1'b0;
    assign          s_last      = 1'b0;

end
endgenerate


// ** handshaking **

generate
if(REGISTER) begin:GEN_REGISTER

end else begin:GEN_NO_REGISTER

    // master
    always @* begin
        if(m_phony) begin
            m_aw_ready      = 1'b0;
            m_w_ready       = !m_w_cnt_zero;
            m_b_valid       = !m_b_cnt_zero;
            m_b_resp        = AXI_RESP_SLVERR;
        end else begin
            m_aw_ready      = !s_phony && s_aw_ready && !m_cnt_max;
            m_w_ready       = !s_phony && s_w_ready && !m_w_cnt_zero;
            m_b_valid       = !s_phony && s_b_valid;
            m_b_resp        = s_b_resp;
        end
    end

    // slave
    always @* begin
        s_aw_addr       = m_aw_addr;
        s_aw_len        = m_aw_len;
        s_w_data        = m_w_data;
        if(s_phony) begin
            s_aw_valid      = 1'b0;
            s_w_valid       = !s_empty;
            s_w_last        = s_last;
            s_w_strb        = {STRB{1'b0}};
            s_b_ready       = !s_b_cnt_zero;
        end else begin
            s_aw_valid      = !m_phony && m_aw_valid && !m_cnt_max;
            s_w_valid       = !m_phony && m_w_valid && !m_w_cnt_zero;
            s_w_last        = m_w_last;
            s_w_strb        = m_w_strb;
            s_b_ready       = !m_phony && m_b_ready;
        end
    end

end
endgenerate

endmodule

