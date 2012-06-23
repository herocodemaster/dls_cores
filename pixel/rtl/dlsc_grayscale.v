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
// Converts color (RGB) images to grayscale using programmable weighting.
// See dlsc_grayscale_core for details.

module dlsc_grayscale #(
    parameter BITS          = 8,            // bits per pixel
    parameter CBITS         = 4,            // bits for coefficients (>= 3)
    parameter CHANNELS      = 1,            // number of pixel channels to support
    
    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_INSTANCE = 32'h00000000  // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // ** Pixel Domain **

    // system
    input   wire                    clk,
    input   wire                    rst,

    // pixels in (color)
    output  wire    [CHANNELS-1:0]          in_ready,
    input   wire    [CHANNELS-1:0]          in_valid,
    input   wire    [(CHANNELS*BITS)-1:0]   in_data_r,
    input   wire    [(CHANNELS*BITS)-1:0]   in_data_g,
    input   wire    [(CHANNELS*BITS)-1:0]   in_data_b,

    // pixels out (grayscale)
    input   wire    [CHANNELS-1:0]          out_ready,
    output  wire    [CHANNELS-1:0]          out_valid,
    output  wire    [(CHANNELS*BITS)-1:0]   out_data,
    
    // ** CSR Domain **

    // system
    input   wire                    csr_clk,
    input   wire                    csr_rst,

    // command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data
);

localparam  CORE_MAGIC          = 32'h926e9bd8; // lower 32 bits of md5sum of "dlsc_grayscale"
localparam  CORE_VERSION        = 32'h20120623;
localparam  CORE_INTERFACE      = 32'h20120623;

genvar j;

// ** Registers **

// 0x00: COMMON: Core magic (RO)
// 0x01: COMMON: Core version (RO)
// 0x02: COMMON: Core interface version (RO)
// 0x03: COMMON: Core instance (RO)
// 0x04: Control (RW)
//  [0]     : enable
// Can only be changed when disabled:
// 0x05: R coefficient (RW)
// 0x06: G coefficient (RW)
// 0x07: B coefficient (RW)

localparam  REG_CORE_MAGIC      = 3'h0,
            REG_CORE_VERSION    = 3'h1,
            REG_CORE_INTERFACE  = 3'h2,
            REG_CORE_INSTANCE   = 3'h3;

localparam  REG_CONTROL         = 3'h4,
            REG_MULT_R          = 3'h5,
            REG_MULT_G          = 3'h6,
            REG_MULT_B          = 3'h7;

wire [2:0]  csr_addr = csr_cmd_addr[4:2];

reg         enabled;

reg  [CBITS-1:0] mult_r;
reg  [CBITS-1:0] mult_g;
reg  [CBITS-1:0] mult_b;

wire        csr_px_rst;

// Write

always @(posedge csr_clk) begin
    if(csr_rst) begin
        enabled     <= 1'b0;
        mult_r      <= 2 << (CBITS-3);  // 0.250 (0.21-0.30)
        mult_g      <= 5 << (CBITS-3);  // 0.625 (0.58-0.72)
        mult_b      <= 1 << (CBITS-3);  // 0.125 (0.07-0.11)
    end else begin
        if(csr_cmd_valid && csr_cmd_write) begin
            if(csr_addr == REG_CONTROL) enabled <= csr_cmd_data[0];
            if(!enabled) begin
                if(csr_addr == REG_MULT_R)  mult_r  <= csr_cmd_data[CBITS-1:0];
                if(csr_addr == REG_MULT_G)  mult_g  <= csr_cmd_data[CBITS-1:0];
                if(csr_addr == REG_MULT_B)  mult_b  <= csr_cmd_data[CBITS-1:0];
            end
        end
        if(csr_px_rst) begin
            enabled     <= 1'b0;
        end
    end
end

// Read mux

always @(posedge csr_clk) begin
    csr_rsp_valid       <= 1'b0;
    csr_rsp_error       <= 1'b0;
    csr_rsp_data        <= 0;
    if(!csr_rst && csr_cmd_valid) begin
        csr_rsp_valid       <= 1'b1;
        if(!csr_cmd_write) begin
            case(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data            <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data            <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data            <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data            <= CORE_INSTANCE;
                REG_CONTROL:        csr_rsp_data[0]         <= enabled;
                REG_MULT_R:         csr_rsp_data[CBITS-1:0] <= mult_r;
                REG_MULT_G:         csr_rsp_data[CBITS-1:0] <= mult_g;
                REG_MULT_B:         csr_rsp_data[CBITS-1:0] <= mult_b;
                default:            csr_rsp_data            <= 0;
            endcase
        end
    end
end


// ** Channels **

wire px_enabled;

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_px (
    .in         ( enabled ),
    .clk        ( clk ),
    .rst        ( rst ),
    .out        ( px_enabled )
);

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_csr (
    .in         ( rst ),
    .clk        ( csr_clk ),
    .rst        ( csr_rst ),
    .out        ( csr_px_rst )
);

wire        rst_i   = rst || !px_enabled;

generate
for(j=0;j<CHANNELS;j=j+1) begin:GEN_CHANNELS

    dlsc_grayscale_core #(
        .BITS       ( BITS ),
        .CBITS      ( CBITS )
    ) dlsc_grayscale_core (
        .clk        ( clk ),
        .rst        ( rst_i ),
        .cfg_mult_r ( mult_r ),
        .cfg_mult_g ( mult_g ),
        .cfg_mult_b ( mult_b ),
        .in_ready   ( in_ready [ j ] ),
        .in_valid   ( in_valid [ j ] ),
        .in_data_r  ( in_data_r[ j*BITS +: BITS ] ),
        .in_data_g  ( in_data_g[ j*BITS +: BITS ] ),
        .in_data_b  ( in_data_b[ j*BITS +: BITS ] ),
        .out_ready  ( out_ready[ j ] ),
        .out_valid  ( out_valid[ j ] ),
        .out_data   ( out_data [ j*BITS +: BITS ] )
    );

end
endgenerate


endmodule

