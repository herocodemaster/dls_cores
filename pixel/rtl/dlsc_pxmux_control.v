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
// Common control logic for pxmux and pxdemux.

module dlsc_pxmux_control #(
    parameter STREAMS       = 1,            // connected pixel sources/sinks
    parameter MAX_H         = 4096,         // maximum supported horizontal resolution
    parameter MAX_V         = 4096,         // maximum supported vertical resolution

    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_MAGIC    = 32'h00000000,
    parameter CORE_INSTANCE = 32'h00000000  // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // ** Pixel Domain **

    // system
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,

    // control
    input   wire                    px_ready,
    output  wire                    px_valid,
    output  reg                     px_last,
    output  wire    [STREAMS-1:0]   px_select,

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
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data
);

`include "dlsc_clog2.vh"

localparam  XB                  = `dlsc_clog2(MAX_H+1);
localparam  YB                  = `dlsc_clog2(MAX_V+1);

localparam  CORE_VERSION        = 32'h20120826;
localparam  CORE_INTERFACE      = 32'h20120826;

localparam  FADDR               = 4;


// ** Registers **

// 0x04: Control (RW)
//  [0]     : enable
//  [1]     : auto mode
//  [2]     : clear FIFO
// 0x05: Status
//  [0]     : px_rst
//  [1]     : FIFO empty
//  [2]     : FIFO half empty
// 0x06: X resolution
// 0x07: Y resolution
// 0x08: FIFO free count
// 0x09: Stream select (FIFO; push on write)

localparam  REG_CORE_MAGIC      = 4'h0,
            REG_CORE_VERSION    = 4'h1,
            REG_CORE_INTERFACE  = 4'h2,
            REG_CORE_INSTANCE   = 4'h3;

localparam  REG_CONTROL         = 4'h4,
            REG_STATUS          = 4'h5,
            REG_X_RES           = 4'h6,
            REG_Y_RES           = 4'h7,
            REG_FIFO_FREE       = 4'h8,
            REG_STREAM_SELECT   = 4'h9;

wire  [3:0]         csr_addr        = csr_cmd_addr[5:2];

reg                 enabled;
reg                 next_enabled;

assign              csr_rst_out     = csr_rst || !enabled;

always @* begin
    next_enabled    = enabled;
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_CONTROL) begin
        next_enabled    = csr_cmd_data[0];
    end
    if(obs_px_rst) begin
        next_enabled    = 1'b0;
    end
end

reg                 auto_mode;
reg                 clear_fifo;

reg  [XB-1:0]       cfg_x;
reg  [YB-1:0]       cfg_y;

wire                obs_px_rst;

wire                fifo_empty;
wire                fifo_half_empty;
wire [FADDR:0]      fifo_free;

always @(posedge csr_clk) begin
    if(csr_rst) begin
        enabled     <= 1'b0;
        auto_mode   <= 1'b0;
        clear_fifo  <= 1'b0;
        cfg_x       <= MAX_H;
        cfg_y       <= MAX_V;
    end else begin
        enabled     <= next_enabled;
        clear_fifo  <= enabled && !next_enabled;
        if(csr_cmd_valid && csr_cmd_write) begin
            if(csr_addr == REG_CONTROL && (!enabled || !next_enabled)) begin
                auto_mode   <= csr_cmd_data[1];
                if(csr_cmd_data[2]) begin
                    clear_fifo  <= 1'b1;
                end
            end
            if(!enabled) begin
                if(csr_addr == REG_X_RES) begin
                    cfg_x       <= csr_cmd_data[XB-1:0];
                end
                if(csr_addr == REG_Y_RES) begin
                    cfg_y       <= csr_cmd_data[YB-1:0];
                end
            end
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
                REG_CONTROL:        csr_rsp_data[1:0]       <= { auto_mode, enabled };
                REG_STATUS:         csr_rsp_data[2:0]       <= { fifo_half_empty, fifo_empty, obs_px_rst };
                REG_X_RES:          csr_rsp_data[XB-1:0]    <= cfg_x;
                REG_Y_RES:          csr_rsp_data[YB-1:0]    <= cfg_y;
                REG_FIFO_FREE:      csr_rsp_data[FADDR:0]   <= fifo_free;
                default:            csr_rsp_data            <= 0;
            endcase
        end
    end
end

// FIFO

wire                fifo_rst        = csr_rst || clear_fifo;

wire                fifo_full;
reg                 fifo_push;
reg  [STREAMS-1:0]  fifo_wr_data;

wire                fifo_pop;
wire [STREAMS-1:0]  fifo_rd_data;

always @* begin
    if(enabled && auto_mode) begin
        fifo_push       = fifo_pop;
        fifo_wr_data    = fifo_rd_data;
    end else begin
        fifo_push       = !fifo_full && csr_cmd_valid && csr_cmd_write && csr_addr == REG_STREAM_SELECT;
        fifo_wr_data    = csr_cmd_data[STREAMS-1:0];
    end
end

dlsc_fifo #(
    .ADDR           ( FADDR ),
    .DATA           ( STREAMS ),
    .ALMOST_EMPTY   ( (2**FADDR)/2 ),
    .FREE           ( 1 ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo (
    .clk            ( csr_clk ),
    .rst            ( fifo_rst ),
    .wr_push        ( fifo_push ),
    .wr_data        ( fifo_wr_data ),
    .wr_full        ( fifo_full ),
    .wr_almost_full (  ),
    .wr_free        ( fifo_free ),
    .rd_pop         ( fifo_pop ),
    .rd_data        ( fifo_rd_data ),
    .rd_empty       ( fifo_empty ),
    .rd_almost_empty ( fifo_half_empty ),
    .rd_count       (  )
);

// Crossing

wire                px_enabled;
assign              px_rst_out      = px_rst || !px_enabled;

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_csr_to_px (
    .in         ( enabled ),
    .clk        ( px_clk ),
    .rst        ( px_rst ),
    .out        ( px_enabled )
);

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_px_to_csr (
    .in         ( { px_rst } ),
    .clk        ( csr_clk ),
    .rst        ( csr_rst ),
    .out        ( { obs_px_rst } )
);

wire                dc_ready;
wire                dc_valid    = enabled && !fifo_empty;
assign              fifo_pop    = dc_ready && dc_valid;

dlsc_domaincross_rvh #(
    .DATA       ( STREAMS )
) dlsc_domaincross_rvh (
    .in_clk     ( csr_clk ),
    .in_rst     ( csr_rst_out ),
    .in_ready   ( dc_ready ),
    .in_valid   ( dc_valid ),
    .in_data    ( fifo_rd_data ),
    .out_clk    ( px_clk ),
    .out_rst    ( px_rst_out ),
    .out_ready  ( px_ready && px_valid && px_last),
    .out_valid  ( px_valid ),
    .out_data   ( px_select )
);

// Control

reg  [XB-1:0]       px_x;
reg                 px_x_last;
reg  [YB-1:0]       px_y;
reg                 px_y_last;

always @(posedge px_clk) begin
    if(px_rst_out) begin
        px_x        <= 1;
        px_y        <= 1;
        px_x_last   <= 1'b0;
        px_y_last   <= 1'b0;
        px_last     <= 1'b0;
    end else if(px_ready && px_valid) begin
        px_x        <=  (px_x + 1);
        px_x_last   <= ((px_x + 1) == cfg_x);
        px_last     <= ((px_x + 1) == cfg_x) && px_y_last;
        if(px_x_last) begin
            px_x        <= 1;
            px_y        <=  (px_y + 1);
            px_y_last   <= ((px_y + 1) == cfg_y);
            if(px_y_last) begin
                px_x        <= 1;
                px_y        <= 1;
                px_x_last   <= 1'b0;
                px_y_last   <= 1'b0;
                px_last     <= 1'b0;
            end
        end
    end
end

endmodule

