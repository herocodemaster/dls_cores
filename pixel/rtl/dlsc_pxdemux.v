// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Distributes a single input pixel stream to multiple downstream sinks. Active
// sinks can be selected at runtime via CSR.

module dlsc_pxdemux #(
    parameter BITS          = 8,            // bits per pixel
    parameter STREAMS       = 1,            // downstream pixel sinks
    parameter MAX_H         = 4096,         // maximum supported horizontal resolution
    parameter MAX_V         = 4096,         // maximum supported vertical resolution
    parameter BUFFER        = 16,           // pixels to buffer per output

    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_INSTANCE = 32'h00000000  // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // ** Pixel Domain **

    // system
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,

    // input
    output  wire                    px_in_ready,
    input   wire                    px_in_valid,
    input   wire    [BITS-1:0]      px_in_data,

    // outputs
    input   wire    [STREAMS-1:0]   px_out_ready,
    output  wire    [STREAMS-1:0]   px_out_valid,
    output  wire    [STREAMS-1:0]   px_out_last,
    output  wire    [(STREAMS*BITS)-1:0] px_out_data,

    // ** CSR Domain **

    // system
    input   wire                    csr_clk,
    input   wire                    csr_rst,
    output  wire                    csr_rst_out,

    // command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // response
    output  wire                    csr_rsp_valid,
    output  wire                    csr_rsp_error,
    output  wire    [31:0]          csr_rsp_data
);

genvar j;

localparam  CORE_MAGIC          = 32'ha4b885ed; // lower 32 bits of md5sum of "dlsc_pxdemux"

// ** control **

wire                px_ready;
wire                px_valid;
wire                px_last;
wire [STREAMS-1:0]  px_select;

dlsc_pxmux_control #(
    .STREAMS            ( STREAMS ),
    .MAX_H              ( MAX_H ),
    .MAX_V              ( MAX_V ),
    .CSR_ADDR           ( CSR_ADDR ),
    .CORE_MAGIC         ( CORE_MAGIC ),
    .CORE_INSTANCE      ( CORE_INSTANCE )
) dlsc_pxmux_control (
    .px_clk             ( px_clk ),
    .px_rst             ( px_rst ),
    .px_rst_out         ( px_rst_out ),
    .px_ready           ( px_ready ),
    .px_valid           ( px_valid ),
    .px_last            ( px_last ),
    .px_select          ( px_select ),
    .csr_clk            ( csr_clk ),
    .csr_rst            ( csr_rst ),
    .csr_rst_out        ( csr_rst_out ),
    .csr_cmd_valid      ( csr_cmd_valid ),
    .csr_cmd_write      ( csr_cmd_write ),
    .csr_cmd_addr       ( csr_cmd_addr ),
    .csr_cmd_data       ( csr_cmd_data ),
    .csr_rsp_valid      ( csr_rsp_valid ),
    .csr_rsp_error      ( csr_rsp_error ),
    .csr_rsp_data       ( csr_rsp_data )
);


// ** demux **

wire [STREAMS-1:0]  wr_almost_full;
reg                 wr_full;

always @(posedge px_clk) begin
    if(px_rst_out) begin
        wr_full     <= 1'b1;
    end else begin
        wr_full     <= |wr_almost_full;
    end
end

assign              px_in_ready     = px_valid && !wr_full;
assign              px_ready        = px_in_ready && px_in_valid;

generate
for(j=0;j<STREAMS;j=j+1) begin:GEN_STREAMS

    wire wr_push = px_in_ready && px_in_valid && px_select[j];

    dlsc_fifo_rvho #(
        .DEPTH          ( BUFFER ),
        .DATA           ( 1+BITS ),
        .ALMOST_FULL    ( 1 )
    ) dlsc_fifo_rvho (
        .clk            ( px_clk ),
        .rst            ( px_rst_out ),
        .wr_push        ( wr_push ),
        .wr_data        ( { px_last, px_in_data } ),
        .wr_full        (  ),
        .wr_almost_full ( wr_almost_full[j] ),
        .wr_free        (  ),
        .rd_ready       ( px_out_ready[j] ),
        .rd_valid       ( px_out_valid[j] ),
        .rd_data        ( { px_out_last[j], px_out_data[ (j*BITS) +: BITS ] } ),
        .rd_almost_empty (  )
    );

end
endgenerate


endmodule

