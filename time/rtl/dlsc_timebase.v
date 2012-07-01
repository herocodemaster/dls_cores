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
//
// Master timebase with fractional counter and multiple divided clock enable
// outputs.
//
// See dlsc_timebase_core for details.

module dlsc_timebase #(
    // ** Timebase **
    parameter PERIOD_IN     = (32'd10  << 24),          // default value for PERIOD_IN register
    parameter PERIOD_OUT    = (32'd100 << 24),          // defalut value for PERIOD_OUT register

    // output dividers (divide down from PERIOD_OUT)
    parameter [31:0] DIV0   = 32'd1,                    // divider for clk_en_out[0];  10 MHz
    parameter [31:0] DIV1   = 32'd10,                   // divider for clk_en_out[1];   1 MHz
    parameter [31:0] DIV2   = 32'd100,                  // divider for clk_en_out[2]; 100 KHz
    parameter [31:0] DIV3   = 32'd1000,                 // divider for clk_en_out[3];  10 KHz
    parameter [31:0] DIV4   = 32'd10000,                // divider for clk_en_out[4];   1 KHz
    parameter [31:0] DIV5   = 32'd100000,               // divider for clk_en_out[5]; 100 Hz
    parameter [31:0] DIV6   = 32'd1000000,              // divider for clk_en_out[6];  10 Hz
    parameter [31:0] DIV7   = 32'd10000000,             // divider for clk_en_out[7];   1 Hz

    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_INSTANCE = 32'h00000000              // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // ** Timebase **

    // system
    input   wire                    clk,
    input   wire                    rst,

    // enable outputs
    output  wire    [7:0]           clk_en_out,
    
    // status
    output  wire                    stopped,            // flag that indicates timebase is stopped (in reset)
    output  wire                    adjusting,          // flag indicating counter is about to be adjusted

    // master counter output
    output  wire    [63:0]          cnt,


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

localparam  CORE_MAGIC          = 32'h17b1ff98; // lower 32 bits of md5sum of "dlsc_timebase"
localparam  CORE_VERSION        = 32'h20120630;
localparam  CORE_INTERFACE      = 32'h20120630;

localparam  OUTPUTS = 8;

/* verilator lint_off WIDTHCONCAT */
localparam [(OUTPUTS*32)-1:0] OUTPUT_DIV = {
    DIV7[31:0],DIV6[31:0],DIV5[31:0],DIV4[31:0],DIV3[31:0],DIV2[31:0],DIV1[31:0],DIV0[31:0] };
/* verilator lint_on WIDTHCONCAT */


// ** Registers **
// 0x4: Control (RW)
//  [0]     : enable
// 0x5: Period in (RW)
//  [31:24] : nanoseconds
//  [23:0]  : fractional nanoseconds
// 0x6: Period out (RW)
//  [31:24] : nanoseconds
//  [23:0]  : fractional nanoseconds
// 0x7: Interrupt flags (RW; write 1 to clear)
//  [7:0]   : clk_en asserted
//  [31]    : counter overflowed
// 0x7: Interrupt select (RW)
// 0xC: Counter low (RO; latches Counter high on read)
// 0xD: Counter high (RO)
// 0xE: Adjust low (WO)
// 0xF: Adjust high (WO; initiates adjust operation on write)

localparam  REG_CORE_MAGIC      = 4'h0,
            REG_CORE_VERSION    = 4'h1,
            REG_CORE_INTERFACE  = 4'h2,
            REG_CORE_INSTANCE   = 4'h3;

localparam  REG_CONTROL         = 4'h4,
            REG_PERIOD_IN       = 4'h5,
            REG_PERIOD_OUT      = 4'h6,
            REG_INT_FLAGS       = 4'h7,
            REG_INT_SELECT      = 4'h8,
            REG_COUNTER_LOW     = 4'hC,
            REG_COUNTER_HIGH    = 4'hD,
            REG_ADJUST_LOW      = 4'hE,
            REG_ADJUST_HIGH     = 4'hF;

wire [3:0]      csr_addr    = csr_cmd_addr[5:2];

reg             enabled;

reg  [31:0]     period_in;
reg  [31:0]     period_out;

reg  [63:32]    cnt_high;

reg             adj_en;
reg  [63:0]     adj_value;

reg  [31:0]     int_select;

always @(posedge clk) begin
    if(rst) begin
        enabled         <= 1'b0;
        period_in       <= PERIOD_IN;
        period_out      <= PERIOD_OUT;
        int_select      <= 0;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        // write
        if(csr_addr == REG_CONTROL) begin
            enabled         <= csr_cmd_data[0];
        end
        if(csr_addr == REG_PERIOD_IN) begin
            period_in       <= csr_cmd_data;
        end
        if(csr_addr == REG_PERIOD_OUT) begin
            period_out      <= csr_cmd_data;
        end
        if(csr_addr == REG_INT_SELECT) begin
            int_select[OUTPUTS-1:0] <= csr_cmd_data[OUTPUTS-1:0];
            int_select[31]          <= csr_cmd_data[31];
        end
    end
end

reg  [31:0]     int_flags;
reg  [31:0]     next_int_flags;
wire            cnt_wrapped;

always @* begin
    next_int_flags = int_flags;
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_FLAGS) begin
        next_int_flags = next_int_flags & ~csr_cmd_data;
    end
    next_int_flags[OUTPUTS-1:0] = next_int_flags[OUTPUTS-1:0] | clk_en_out;
    next_int_flags[31]          = next_int_flags[31] | cnt_wrapped;
    next_int_flags[30:OUTPUTS]  = 0;
end

always @(posedge clk) begin
    if(rst) begin
        int_flags       <= 0;
        csr_int         <= 1'b0;
    end else begin
        int_flags       <= next_int_flags;
        csr_int         <= |(int_flags & int_select);
    end
end


always @(posedge clk) begin
    if(rst) begin
        adj_en          <= 1'b0;
    end else begin
        adj_en          <= 1'b0; // adjust should only assert for 1 cycle
        if(csr_cmd_valid && csr_cmd_write) begin
            // write
            if(csr_addr == REG_ADJUST_HIGH) begin
                // initiate adjust on write to high
                // (low must always be written first)
                adj_en          <= 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    if(csr_cmd_valid && csr_cmd_write) begin
        // write
        if(csr_addr == REG_ADJUST_LOW) begin
            adj_value[31:0]     <= csr_cmd_data;
        end
        if(csr_addr == REG_ADJUST_HIGH) begin
            adj_value[63:32]    <= csr_cmd_data;
        end
    end
end

always @(posedge clk) begin
    if(csr_cmd_valid && !csr_cmd_write) begin
        // read
        if(csr_addr == REG_COUNTER_LOW) begin
            // latch high bits when low is read
            cnt_high[63:32]     <= cnt[63:32];
        end
    end
end

always @(posedge clk) begin
    if(rst || csr_rsp_valid) begin
        // clear CSR response
        csr_rsp_valid   <= 1'b0;
        csr_rsp_error   <= 1'b0;
        csr_rsp_data    <= 0;
    end else if(csr_cmd_valid) begin
        // generate CSR response
        csr_rsp_valid   <= 1'b1;
        csr_rsp_error   <= 1'b0;
        csr_rsp_data    <= 0;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data        <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data        <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data        <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data        <= CORE_INSTANCE;
                REG_CONTROL:        csr_rsp_data[0]     <= enabled;
                REG_PERIOD_IN:      csr_rsp_data        <= period_in;
                REG_PERIOD_OUT:     csr_rsp_data        <= period_out;
                REG_INT_FLAGS:      csr_rsp_data        <= int_flags;
                REG_INT_SELECT:     csr_rsp_data        <= int_select;
                REG_COUNTER_LOW:    csr_rsp_data        <= cnt[31:0];           // taken directly from counter
                REG_COUNTER_HIGH:   csr_rsp_data        <= cnt_high[63:32];     // latched value of counter
                default:            csr_rsp_data        <= 0;
            endcase
        end
    end
end


// ** Timebase **

wire rst_timebase = rst || !enabled;

dlsc_timebase_core #(
    .CNTB           ( 64 ),
    .PERB           ( 8 ),
    .SUBB           ( 24 ),
    .OUTPUTS        ( 8 ),
    .OUTPUT_DIV     ( OUTPUT_DIV )
) dlsc_timebase_core (
    .clk            ( clk ),
    .rst            ( rst_timebase ),
    .clk_en_out     ( clk_en_out ),
    .cfg_period_in  ( period_in ),
    .cfg_period_out ( period_out ),
    .cfg_adj_en     ( adj_en ),
    .cfg_adj_value  ( adj_value ),
    .stopped        ( stopped ),
    .adjusting      ( adjusting ),
    .cnt            ( cnt ),
    .cnt_wrapped    ( cnt_wrapped )
);


endmodule

