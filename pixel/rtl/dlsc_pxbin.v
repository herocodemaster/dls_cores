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
// Performs pixel binning to reduce image resolution. For Bayer inputs, will
// also convert to RGB when binning.

module dlsc_pxbin #(
    // ** Clock Domains **
    parameter CSR_DOMAIN        = 0,
    parameter PX_DOMAIN         = 1,
    // ** Config **
    parameter BITS              = 8,                    // bits per pixel
    parameter MAX_WIDTH         = 1024,                 // maximum horizontal resolution
    parameter MAX_HEIGHT        = 1024,                 // maximum vertical resolution
    parameter MAX_BIN           = 8,                    // maximum binning factor
    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_INSTANCE     = 32'h00000000          // 32-bit identifier to place in REG_CORE_INSTANCE field
) (

    // ** CSR Domain **

    // System
    input   wire                    csr_clk,
    input   wire                    csr_rst,
    output  wire                    csr_rst_out,        // asserted when engine is disabled

    // Status
    output  wire                    csr_enabled,        // asserted when engine is enabled
    
    // CSR command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // CSR response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data,

    // ** Pixel Domain **
    
    // System
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,         // asserted when engine is disabled
    
    // pixels in (raw)
    output  wire                    px_in_ready,
    input   wire                    px_in_valid,
    input   wire    [BITS-1:0]      px_in_data,

    // pixels out (color or raw; for raw, all channels are the same)
    input   wire                    px_out_ready,
    output  wire                    px_out_valid,
    output  wire    [BITS-1:0]      px_out_data_r,
    output  wire    [BITS-1:0]      px_out_data_g,
    output  wire    [BITS-1:0]      px_out_data_b
);

`include "dlsc_clog2.vh"

localparam XB       = `dlsc_clog2(MAX_WIDTH);   // bits for image width
localparam YB       = `dlsc_clog2(MAX_HEIGHT);  // bits for image height
localparam BINB     = `dlsc_clog2(MAX_BIN);     // bits for selecting bin factor

localparam  CORE_MAGIC          = 32'h47cc0406; // lower 32 bits of md5sum of "dlsc_pxbin"
localparam  CORE_VERSION        = 32'h20120715;
localparam  CORE_INTERFACE      = 32'h20120715;

// ** Registers **
//
// 0x4: Control (RW)
//  [0]     : enable (cleared on error)
// 0x5: Status (RO)
//  [0]     : pixel domain in reset
//
// The following registers can only be written when disabled:
//
// 0x8: Image width; 0-based (RW)
// 0x9: Image height; 0-based (RW)
// 0xA: Horizontal binning; 0-based (RW)
// 0xB: Vertical binning; 0-based (RW)
// 0xC: Bayer (RW)
//  [0]     : enable bayer-aware binning
//  [1]     : first row has red pixels
//  [2]     : first pixel is green

localparam  REG_CORE_MAGIC          = 4'h0,
            REG_CORE_VERSION        = 4'h1,
            REG_CORE_INTERFACE      = 4'h2,
            REG_CORE_INSTANCE       = 4'h3;

localparam  REG_CONTROL             = 4'h4,
            REG_STATUS              = 4'h5,
            REG_WIDTH               = 4'h8,
            REG_HEIGHT              = 4'h9,
            REG_BIN_X               = 4'hA,
            REG_BIN_Y               = 4'hB,
            REG_BAYER               = 4'hC;

wire [3:0]          csr_addr        = csr_cmd_addr[5:2];

reg                 enabled;
wire [31:0]         csr_control     = { 31'd0, enabled };

assign              csr_rst_out     = csr_rst || !enabled;
assign              csr_enabled     = enabled;

wire                obs_px_rst;
wire [31:0]         csr_status      = { 31'd0, obs_px_rst };

reg  [XB-1:0]       cfg_width;
reg  [YB-1:0]       cfg_height;
reg  [BINB-1:0]     cfg_bin_x;
reg  [BINB-1:0]     cfg_bin_y;

reg                 cfg_bayer;
reg                 cfg_first_r;
reg                 cfg_first_g;
wire [31:0]         csr_bayer       = { 29'd0, cfg_first_g, cfg_first_r, cfg_bayer };

// ** register write **

always @(posedge csr_clk) begin
    if(csr_rst) begin
        enabled     <= 1'b0;
        /* verilator lint_off WIDTH */
        cfg_width   <= (MAX_WIDTH-1);
        cfg_height  <= (MAX_HEIGHT-1);
        /* verilator lint_on WIDTH */
        cfg_bin_x   <= 0;
        cfg_bin_y   <= 0;
        cfg_bayer   <= 1'b0;
        cfg_first_r <= 1'b0;
        cfg_first_g <= 1'b0;
    end else begin
        if(csr_cmd_valid && csr_cmd_write) begin
            if(csr_addr == REG_CONTROL) begin
                enabled     <= csr_cmd_data[0];
            end
        end
        if(csr_cmd_valid && csr_cmd_write && !enabled) begin
            if(csr_addr == REG_WIDTH) begin
                cfg_width   <= csr_cmd_data[XB-1:0];
            end
            if(csr_addr == REG_HEIGHT) begin
                cfg_height  <= csr_cmd_data[YB-1:0];
            end
            if(csr_addr == REG_BIN_X) begin
                cfg_bin_x   <= csr_cmd_data[BINB-1:0];
            end
            if(csr_addr == REG_BIN_Y) begin
                cfg_bin_y   <= csr_cmd_data[BINB-1:0];
            end
            if(csr_addr == REG_BAYER) begin
                cfg_bayer   <= csr_cmd_data[0];
                cfg_first_r <= csr_cmd_data[1];
                cfg_first_g <= csr_cmd_data[2];
            end
        end
        if(obs_px_rst) begin
            enabled     <= 1'b0;
        end
    end
end

// ** register read **

always @(posedge csr_clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!csr_rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:         csr_rsp_data            <= CORE_MAGIC;
                REG_CORE_VERSION:       csr_rsp_data            <= CORE_VERSION;
                REG_CORE_INTERFACE:     csr_rsp_data            <= CORE_INTERFACE;
                REG_CORE_INSTANCE:      csr_rsp_data            <= CORE_INSTANCE;
                REG_CONTROL:            csr_rsp_data            <= csr_control;
                REG_STATUS:             csr_rsp_data            <= csr_status;
                REG_WIDTH:              csr_rsp_data[XB-1:0]    <= cfg_width;
                REG_HEIGHT:             csr_rsp_data[YB-1:0]    <= cfg_height;
                REG_BIN_X:              csr_rsp_data[BINB-1:0]  <= cfg_bin_x;
                REG_BIN_Y:              csr_rsp_data[BINB-1:0]  <= cfg_bin_y;
                REG_BAYER:              csr_rsp_data            <= csr_bayer;
                default:                csr_rsp_data            <= 0;
            endcase
        end
    end
end

// ** synchronization **

// CSR -> PX

wire    px_enabled;
assign  px_rst_out  = px_rst || !px_enabled;

dlsc_syncflop #(
    .BYPASS     ( CSR_DOMAIN == PX_DOMAIN ),
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_csr_to_px (
    .in         ( enabled ),
    .clk        ( px_clk ),
    .rst        ( px_rst ),
    .out        ( px_enabled )
);

// PX -> CSR

dlsc_syncflop #(
    .BYPASS     ( PX_DOMAIN == CSR_DOMAIN ),
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_px_to_csr (
    .in         ( px_rst ),
    .clk        ( csr_clk ),
    .rst        ( csr_rst ),
    .out        ( obs_px_rst )
);

// ** pixel binning core **

dlsc_pxbin_core #(
    .BITS           ( BITS ),
    .WIDTH          ( MAX_WIDTH ),
    .XB             ( XB ),
    .YB             ( YB ),
    .BINB           ( BINB )
) dlsc_pxbin_core (
    .clk            ( px_clk ),
    .rst            ( px_rst_out ),
    .cfg_width      ( cfg_width ),
    .cfg_height     ( cfg_height ),
    .cfg_bin_x      ( cfg_bin_x ),
    .cfg_bin_y      ( cfg_bin_y ),
    .cfg_bayer      ( cfg_bayer ),
    .cfg_first_r    ( cfg_first_r ),
    .cfg_first_g    ( cfg_first_g ),
    .in_ready       ( px_in_ready ),
    .in_valid       ( px_in_valid ),
    .in_data        ( px_in_data ),
    .out_ready      ( px_out_ready ),
    .out_valid      ( px_out_valid ),
    .out_data_r     ( px_out_data_r ),
    .out_data_g     ( px_out_data_g ),
    .out_data_b     ( px_out_data_b )
);

endmodule

