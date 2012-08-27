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
// Applies a programmable gain to a pixel stream. Gains can be independently set
// per image channel. Gains may be synchronously changed each frame via a FIFO
// of gain values set via CSR.

module dlsc_pxgain #(
    parameter BITS          = 8,            // bits per pixel channel
    parameter CHANNELS      = 1,            // channels per pixel (1-4)
    parameter MAX_H         = 4096,         // maximum supported horizontal resolution
    parameter MAX_V         = 4096,         // maximum supported vertical resolution
    parameter GAINB         = 17,           // bits for gain values
    parameter DIVB          = 12,           // post-divide amount

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
    input   wire    [(CHANNELS*BITS)-1:0] px_in_data,

    // outputs
    input   wire                    px_out_ready,
    output  wire                    px_out_valid,
    output  wire                    px_out_last,
    output  wire    [(CHANNELS*BITS)-1:0] px_out_data,

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


// ** control **

wire                px_ready;
wire                px_valid;
wire                px_last;
wire [(CHANNELS*GAINB)-1:0] px_gain;

dlsc_pxgain_control #(
    .CHANNELS           ( CHANNELS ),
    .MAX_H              ( MAX_H ),
    .MAX_V              ( MAX_V ),
    .GAINB              ( GAINB ),
    .DIVB               ( DIVB ),
    .CSR_ADDR           ( CSR_ADDR ),
    .CORE_INSTANCE      ( CORE_INSTANCE )
) dlsc_pxgain_control (
    .px_clk             ( px_clk ),
    .px_rst             ( px_rst ),
    .px_rst_out         ( px_rst_out ),
    .px_ready           ( px_ready ),
    .px_valid           ( px_valid ),
    .px_last            ( px_last ),
    .px_gain            ( px_gain ),
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


// ** gain **

wire [(CHANNELS*BITS)-1:0] c5_data;

generate
for(j=0;j<CHANNELS;j=j+1) begin:GEN_CHANNELS

    // multiply
    wire [GAINB+BITS     -1:0]  c4_data_pre;
    dlsc_mult #(
        .SIGNED         ( 0 ),
        .DATA0          ( GAINB ),
        .DATA1          ( BITS ),
        .OUT            ( GAINB+BITS ),
        .PIPELINE       ( 4-0 )
    ) dlsc_mult (
        .clk            ( px_clk ),
        .clk_en         ( 1'b1 ),
        .in0            ( px_gain[ (j*GAINB) +: GAINB ] ),
        .in1            ( px_in_data[ (j*BITS) +: BITS ] ),
        .out            ( c4_data_pre )
    );

    // post-divide
    wire [GAINB+BITS-DIVB-1:0]  c4_data     = c4_data_pre[GAINB+BITS-1 : DIVB];
    wire                        c4_clamp    = |c4_data[GAINB+BITS-DIVB-1 : BITS];

    // clamp
    reg  [BITS-1:0]             c5_data_pre;
    always @(posedge px_clk) begin
        if(c4_clamp) begin
            c5_data_pre <= {BITS{1'b1}};
        end else begin
            c5_data_pre <= c4_data[BITS-1:0];
        end
    end

    assign c5_data[ (j*BITS) +: BITS ] = c5_data_pre;

end
endgenerate

wire            c5_valid;
wire            c5_last;

dlsc_pipedelay_valid #(
    .DATA           ( 1 ),
    .DELAY          ( 5-0 )
) dlsc_pipedelay_valid_c0_c5 (
    .clk            ( px_clk ),
    .rst            ( px_rst_out ),
    .in_valid       ( px_in_ready && px_in_valid ),
    .in_data        ( px_last ),
    .out_valid      ( c5_valid ),
    .out_data       ( c5_last )
);


// ** buffering **

wire            wr_almost_full;

assign          px_in_ready     = px_valid && !wr_almost_full;
assign          px_ready        = px_in_ready && px_in_valid;

dlsc_fifo_rvho #(
    .DEPTH          ( 16 ),
    .DATA           ( 1 + (CHANNELS*BITS) ),
    .ALMOST_FULL    ( 6 )
) dlsc_fifo_rvho (
    .clk            ( px_clk ),
    .rst            ( px_rst_out ),
    .wr_push        ( c5_valid ),
    .wr_data        ( { c5_last, c5_data } ),
    .wr_full        (  ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( px_out_ready ),
    .rd_valid       ( px_out_valid ),
    .rd_data        ( { px_out_last, px_out_data } ),
    .rd_almost_empty (  )
);

endmodule

