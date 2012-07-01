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
// Quadrature decoder with index support.
//
// See dlsc_quad_decoder_core.v for details.

module dlsc_quad_decoder #(
    // ** Quad Decode **
    parameter FILTER            = 16,                   // depth of glitch filters
    parameter BITS              = 16,                   // bits for counter (<= 32)

    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_INSTANCE     = 32'h00000000          // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // system
    input   wire                    clk,
    input   wire                    rst,
    
    // quadrature inputs
    input   wire                    in_a,
    input   wire                    in_b,
    input   wire                    in_z,               // index

    // filtered quadrature signals
    output  wire                    out_a,
    output  wire                    out_b,
    output  wire                    out_z,

    // decoded quadrature signals
    output  wire                    quad_en,            // valid quadrature transition detected
    output  wire                    quad_dir,           // 1: incrementing, 0: decrementing
    output  wire                    quad_index,         // filtered and qualified index signal

    // counter
    output  wire    [BITS-1:0]      count,

    // ** Register Bus **

    // command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data,

    // interrupt
    output  reg                     csr_int
);

localparam  CORE_MAGIC          = 32'hdd16d54c; // lower 32 bits of md5sum of "dlsc_quad_decoder"
localparam  CORE_VERSION        = 32'h20120701;
localparam  CORE_INTERFACE      = 32'h20120701;

// ** Registers **
// 0x4: Control (RW)
//  [0]     : enable
//  [1]     : clear counter on read
//  [2]     : clear counter on index pulse
//  [7:4]   : index qual
// 0x5: Count min (RW)
// 0x6: Count max (RW)
// 0x7: Interrupt flags (RW; write 1 to clear)
//  [0]     : quad state changed
//  [1]     : illegal quadrature state transition detected
//  [2]     : got qualified index pulse
//  [3]     : index pulse occurred when count was not 0
//  [4]     : counter wrapped min->max
//  [5]     : counter wrapped max->min
// 0x8: Interrupt select (RW)
// 0x9: Status (RO)
//  [0]     : a state
//  [1]     : b state
//  [2]     : z state
// 0xA: Count (RO; clear on read (if enabled))
// 0xB: Index count (RO)

localparam  REG_CORE_MAGIC      = 4'h0,
            REG_CORE_VERSION    = 4'h1,
            REG_CORE_INTERFACE  = 4'h2,
            REG_CORE_INSTANCE   = 4'h3;

localparam  REG_CONTROL         = 4'h4,
            REG_COUNT_MIN       = 4'h5,
            REG_COUNT_MAX       = 4'h6,
            REG_INT_FLAGS       = 4'h7,
            REG_INT_SELECT      = 4'h8,
            REG_STATUS          = 4'h9,
            REG_COUNT           = 4'hA,
            REG_INDEX           = 4'hB;

wire [3:0]      csr_addr        = csr_cmd_addr[5:2];

reg             enabled;
reg             read_clr;
reg             index_clr;
reg  [3:0]      index_qual;

reg  [BITS-1:0] count_min;
reg  [BITS-1:0] count_max;

wire            count_wrap_min;
wire            count_wrap_max;
wire            error_index;
wire            error_quad;

reg  [5:0]      int_flags;
reg  [5:0]      int_select;

wire [BITS-1:0] count;
wire [BITS-1:0] index_count;

wire [31:0]     csr_control     = { 24'd0, index_qual, 1'b0, index_clr, read_clr, enabled };

// sign-extend counts
wire [31:0]     csr_count_min   = { {(32-BITS){count_min  [BITS-1]}} , count_min   };
wire [31:0]     csr_count_max   = { {(32-BITS){count_max  [BITS-1]}} , count_max   };
wire [31:0]     csr_count       = { {(32-BITS){count      [BITS-1]}} , count       };
wire [31:0]     csr_index_count = { {(32-BITS){index_count[BITS-1]}} , index_count };

wire [31:0]     csr_status      = { 29'd0, out_z, out_b, out_z };

always @(posedge clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data        <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data        <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data        <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data        <= CORE_INSTANCE;
                REG_CONTROL:        csr_rsp_data        <= csr_control;
                REG_COUNT_MIN:      csr_rsp_data        <= csr_count_min;
                REG_COUNT_MAX:      csr_rsp_data        <= csr_count_max;
                REG_INT_FLAGS:      csr_rsp_data[5:0]   <= int_flags;
                REG_INT_SELECT:     csr_rsp_data[5:0]   <= int_select;
                REG_STATUS:         csr_rsp_data        <= csr_status;
                REG_COUNT:          csr_rsp_data        <= csr_count;
                REG_INDEX:          csr_rsp_data        <= csr_index_count;
                default:            csr_rsp_data        <= 0;
            endcase
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        enabled     <= 1'b0;
        read_clr    <= 1'b0;
        index_clr   <= 1'b0;
        index_qual  <= 0;
        count_min   <= {1'b1,{(BITS-1){1'b0}}}; // most negative
        count_max   <= {1'b0,{(BITS-1){1'b1}}}; // most positive
        int_select  <= 0;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_CONTROL) begin
            enabled     <= csr_cmd_data[0];
            read_clr    <= csr_cmd_data[1];
            index_clr   <= csr_cmd_data[2];
            index_qual  <= csr_cmd_data[7:4];
        end
        if(csr_addr == REG_COUNT_MIN) begin
            count_min   <= csr_cmd_data[BITS-1:0];
        end
        if(csr_addr == REG_COUNT_MAX) begin
            count_max   <= csr_cmd_data[BITS-1:0];
        end
        if(csr_addr == REG_INT_SELECT) begin
            int_select  <= csr_cmd_data[5:0];
        end
    end
end

reg  [5:0]      next_int_flags;
always @* begin
    next_int_flags  = int_flags;
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_FLAGS) begin
        next_int_flags  = next_int_flags & ~csr_cmd_data[5:0];
    end
    if(quad_en)         next_int_flags[0]   = 1'b1;
    if(error_quad)      next_int_flags[1]   = 1'b1;
    if(quad_index)      next_int_flags[2]   = 1'b1;
    if(error_index)     next_int_flags[3]   = 1'b1;
    if(count_wrap_min)  next_int_flags[4]   = 1'b1;
    if(count_wrap_max)  next_int_flags[5]   = 1'b1;
end

always @(posedge clk) begin
    if(rst) begin
        int_flags   <= 0;
        csr_int     <= 1'b0;
    end else begin
        int_flags   <= next_int_flags;
        csr_int     <= |(int_flags & int_select);
    end
end

wire            count_read      = (read_clr && csr_cmd_valid && !csr_cmd_write && csr_addr == REG_COUNT);

dlsc_quad_decoder_core #(
    .FILTER         ( FILTER ),
    .BITS           ( BITS )
) dlsc_quad_decoder_core (
    .clk            ( clk ),
    .clk_en_filter  ( 1'b1 ),
    .rst            ( rst || !enabled ),
    .cfg_count_min  ( count_min ),
    .cfg_count_max  ( count_max ),
    .cfg_index_qual ( index_qual ),
    .cfg_index_clr  ( index_clr ),
    .in_a           ( in_a ),
    .in_b           ( in_b ),
    .in_z           ( in_z ),
    .out_a          ( out_a ),
    .out_b          ( out_b ),
    .out_z          ( out_z ),
    .quad_en        ( quad_en ),
    .quad_dir       ( quad_dir ),
    .quad_index     ( quad_index ),
    .count_read     ( count_read ),
    .count          ( count ),
    .count_wrap_min ( count_wrap_min ),
    .count_wrap_max ( count_wrap_max ),
    .index_count    ( index_count ),
    .error_index    ( error_index ),
    .error_quad     ( error_quad )
);


endmodule

