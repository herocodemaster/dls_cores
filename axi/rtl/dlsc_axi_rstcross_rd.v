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
// This particular module is for just the AXI read channel (AR,R).

module dlsc_axi_rstcross_rd #(
    parameter AR_BITS           = 1,
    parameter R_BITS            = 1,
    parameter AR_RESET          = {AR_BITS{1'b0}},
    parameter R_RESET           = {R_BITS{1'b0}},
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
    input   wire    [R_BITS-1:0]    s_r
);

`include "dlsc_clog2.vh"

localparam MAX_BITS     = `dlsc_clog2(MAX_OUTSTANDING+1);


// phony flags indicate when phony data is being supplied to make up for
// data that was lost in reset
reg m_phony = 1'b0;
reg s_phony = 1'b0;


// ** master **

wire                m_empty;

// generate phony data if other side enters reset
always @(posedge clk) begin
    if(s_rst) begin
        m_phony         <= 1'b1;
    end else if(m_empty) begin
        m_phony         <= 1'b0;
    end
end


// track R beats
reg  [LEN_BITS-1:0] m_r_cnt;

always @(posedge clk) begin
    if(m_rst) begin
        m_r_cnt     <= 0;
    end else if(m_r_ready && m_r_valid) begin
        m_r_cnt     <= m_r_last ? 0 : (m_r_cnt + 1);
    end
end


// track command lengths (in order to produce correct w_last)
wire [MAX_BITS-1:0] m_r_len;
wire                m_full;

dlsc_fifo_shiftreg #(
    .DATA           ( LEN_BITS ),
    .DEPTH          ( MAX_OUTSTANDING )
) dlsc_fifo_shiftreg_inst (
    .clk            ( clk ),
    .rst            ( m_rst ),
    .push_en        ( m_ar_ready && m_ar_valid ),
    .push_data      ( m_ar_len ),
    .pop_en         ( m_r_ready && m_r_valid && m_r_last ),
    .pop_data       ( m_r_len ),
    .empty          ( m_empty ),
    .full           ( m_full ),
    .almost_empty   (  ),
    .almost_full    (  )
);


assign m_ar_ready   = m_phony ? ( 1'b0 )                : ( !s_phony && s_ar_ready && !m_full );

assign m_r_valid    = m_phony ? ( !m_empty )            : ( !s_phony && s_r_valid );
assign m_r_last     = m_phony ? ( m_r_cnt == m_r_len )  : ( s_r_last );
assign m_r          = m_phony ? ( R_RESET )             : ( s_r );


// ** slave **

reg  [MAX_BITS-1:0] s_r_cnt         = 0;
reg                 s_r_cnt_zero    = 1'b1;

// generate phony data if other side enters reset
always @(posedge clk) begin
    if(m_rst) begin
        s_phony         <= 1'b1;
    end else if(s_r_cnt_zero) begin
        s_phony         <= 1'b0;
    end
end


// track AR/R beats
wire s_r_inc = (s_ar_ready && s_ar_valid);
wire s_r_dec = (s_r_ready && s_r_valid && s_r_last);

always @(posedge clk) begin
    if(s_rst) begin
        s_r_cnt         <= 0;
        s_r_cnt_zero    <= 1'b1;
    end else begin
        if( s_r_inc && !s_r_dec) begin
            s_r_cnt         <= s_r_cnt + 1;
            s_r_cnt_zero    <= 1'b0;
        end
        if(!s_r_inc &&  s_r_dec) begin
            s_r_cnt         <= s_r_cnt - 1;
            s_r_cnt_zero    <= (s_r_cnt == 1);
        end
    end
end


assign s_ar_valid   = s_phony ? ( 1'b0 )                : ( !m_phony && m_ar_valid && !m_full );
assign s_ar_len     = m_ar_len;
assign s_ar         = m_ar;

assign s_r_ready    = s_phony ? ( !s_r_cnt_zero )       : ( !m_phony && m_r_ready );


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(!s_rst) begin
        if(s_r_inc && !s_r_dec && &s_r_cnt) begin
            `dlsc_error("s_r_cnt overflow");
        end
        if(!s_r_inc && s_r_dec && s_r_cnt == 0) begin
            `dlsc_error("s_r_cnt underflow");
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule


