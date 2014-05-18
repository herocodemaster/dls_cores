// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
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
// Row buffer memory and fill/repeat logic for dlsc_window_front.

module dlsc_window_front_ram #(
    parameter BITS          = 8,            // bits per pixel
    parameter WINX          = 3,            // horizontal window size (odd; >= 1)
    parameter WINY          = 3,            // vertical window size (odd; >= 1)
    parameter MAXX          = 1024,         // max input image width
    parameter XB            = 10,           // bits for horizontal resolution
    // edge mode (decoded; one-hot)
    parameter EM_FILL       = 0,
    parameter EM_REPEAT     = 0,
    parameter EM_BAYER      = 0,
    parameter EM_NONE       = 1
) (
    // system
    input   wire                    clk,

    // config
    input   wire    [BITS-1:0]      cfg_fill,

    // control
    input   wire    [XB-1:0]        c1_addr,
    input   wire                    c1_rd_en,
    input   wire                    c2_wr_en,
    input   wire                    c3_prime,
    input   wire                    c3_post,

    // input
    input   wire    [BITS-1:0]      c3_in_data,

    // output
    output  wire    [WINY*BITS-1:0] c4_out_data
);

`include "dlsc_synthesis.vh"

localparam WINY21 = (WINY/2) - 1;

integer i;

generate
if(WINY>=3) begin:GEN_WINY

    wire [(WINY-1)*BITS-1:0] c3_rd_data;

    // generate write data

    `DLSC_PIPE_REG reg [(WINY-1)*BITS-1:0] c4_wr_data;

    always @(posedge clk) begin
        // default; just shift rows up
        for(i=0;i<(WINY-2);i=i+1) begin
            c4_wr_data[ i*BITS +: BITS ] <= c3_rd_data[ (i+1)*BITS +: BITS ];
        end
        c4_wr_data[ (WINY-2)*BITS +: BITS ] <= c3_in_data;

        if(EM_FILL) begin
            for(i=((WINY/2)-1);i<(WINY-2);i=i+1) begin
                c4_wr_data[ i*BITS +: BITS ] <= (!c3_prime) ? c3_rd_data[ (i+1)*BITS +: BITS ] : cfg_fill;
            end
            c4_wr_data[ (WINY-2)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : cfg_fill;
        end
        if(EM_REPEAT) begin
            for(i=((WINY/2)-1);i<(WINY-2);i=i+1) begin
                c4_wr_data[ i*BITS +: BITS ] <= (!c3_prime) ? c3_rd_data[ (i+1)*BITS +: BITS ] : c3_in_data;
            end
            c4_wr_data[ (WINY-2)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : c3_rd_data[ (WINY-2)*BITS +: BITS ];
        end
        if(EM_BAYER) begin
            if(WINY > 3) for(i=((WINY/2)-2);i<(WINY-3);i=i+1) if((i%2)==1) begin
                c4_wr_data[ i*BITS +: BITS ] <= (!c3_prime) ? c3_rd_data[ (i+1)*BITS +: BITS ] : c3_in_data;
            end
            c4_wr_data[ (WINY-2)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : c3_rd_data[ (WINY-3)*BITS +: BITS ];
        end
    end

    // generate output data

    `DLSC_PIPE_REG reg [WINY*BITS-1:0] c4_out_data_r;
    assign c4_out_data = c4_out_data_r;

    always @(posedge clk) begin
        // default
        for(i=0;i<(WINY-1);i=i+1) begin
            c4_out_data_r[ i*BITS +: BITS ] <= c3_rd_data[ i*BITS +: BITS ];
        end
        c4_out_data_r[ (WINY-1)*BITS +: BITS ] <= c3_in_data;

        if(EM_FILL) begin
            if(WINX > 1) for(i=0;i<(WINY-1);i=i+1) begin
                c4_out_data_r[ i*BITS +: BITS ] <= (!c3_prime) ? c3_rd_data[ i*BITS +: BITS ] : cfg_fill;
            end
            c4_out_data_r[ (WINY-1)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : cfg_fill;
        end
        if(EM_REPEAT) begin
            c4_out_data_r[ (WINY-1)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : c3_rd_data[ (WINY-2)*BITS +: BITS ];
        end
        if(EM_BAYER) begin
            if(WINY <= 3) begin
                c4_out_data_r[ 0 +: BITS ] <= (!c3_prime) ? c3_rd_data[ 0 +: BITS ] : c3_in_data;
            end
            c4_out_data_r[ (WINY-1)*BITS +: BITS ] <= (!c3_post) ? c3_in_data : c3_rd_data[ (WINY-3)*BITS +: BITS ];
        end
    end

    // RAM

    reg [XB-1:0] c2_addr;
    always @(posedge clk) begin
        c2_addr <= c1_addr;
    end

    dlsc_ram_dp #(
        .DATA           ( (WINY-1)*BITS ),
        .ADDR           ( XB ),
        .DEPTH          ( MAXX ),
        .PIPELINE_WR    ( 2 ),
        .PIPELINE_WR_DATA ( 0 ),
        .PIPELINE_RD    ( 2 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp (
        .write_clk      ( clk ),
        .write_en       ( c2_wr_en ),
        .write_addr     ( c2_addr ),
        .write_data     ( c4_wr_data ),
        .read_clk       ( clk ),
        .read_en        ( c1_rd_en ),
        .read_addr      ( c1_addr ),
        .read_data      ( c3_rd_data )
    );

end else begin:GEN_NO_WINY

    reg [BITS-1:0] c4_out_data_r;
    assign c4_out_data = c4_out_data_r;

    always @(posedge clk) begin
        c4_out_data_r <= c3_in_data;
    end

end
endgenerate

endmodule

