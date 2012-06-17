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
// Master timebase with fractional-n clock prescaler, master counter, and
// multiple divided clock enable outputs.
//
// See dlsc_timebase_core for details.

module dlsc_timebase #(
    // ** Timebase **
    parameter FREQ_IN       = 100000000,                // nominal clk input frequency (in Hz); can be changed via registers

    parameter CNT_RATE      = 10000000,                 // increment rate for master counter (in Hz; < FREQ_IN)
    parameter CNT_INC       = (1000000000/CNT_RATE),    // increment amount for master counter (defaults to effective increment rate of 1 GHz)

    // output dividers (divide down from CNT_RATE)
    parameter [31:0] DIV0   = 32'd1,                    // divider for clk_en_out[0];  10 MHz
    parameter [31:0] DIV1   = 32'd10,                   // divider for clk_en_out[1];   1 MHz
    parameter [31:0] DIV2   = 32'd100,                  // divider for clk_en_out[2]; 100 KHz
    parameter [31:0] DIV3   = 32'd1000,                 // divider for clk_en_out[3];  10 KHz
    parameter [31:0] DIV4   = 32'd10000,                // divider for clk_en_out[4];   1 KHz
    parameter [31:0] DIV5   = 32'd100000,               // divider for clk_en_out[5]; 100 Hz
    parameter [31:0] DIV6   = 32'd1000000,              // divider for clk_en_out[6];  10 Hz
    parameter [31:0] DIV7   = 32'd10000000,             // divider for clk_en_out[7];   1 Hz

    // ** CSR **
    parameter CSR_ADDR      = 32
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
    output  reg     [31:0]          csr_rsp_data
);

/* verilator lint_off WIDTHCONCAT */
localparam [(8*32)-1:0] OUTPUT_DIV = {
    DIV7[31:0],DIV6[31:0],DIV5[31:0],DIV4[31:0],DIV3[31:0],DIV2[31:0],DIV1[31:0],DIV0[31:0] };
/* verilator lint_on WIDTHCONCAT */


// ** Registers **
// 0x0: Control (RW)
//  [0]     : enable
// 0x1: Frequency (RW)
// 0x4: Counter low (RO; latches Counter high on read)
// 0x5: Counter high (RO)
// 0x6: Adjust low (WO)
// 0x7: Adjust high (WO; initiates adjust operation on write)

localparam  REG_CONTROL         = 3'h0,
            REG_FREQUENCY       = 3'h1,
            REG_COUNTER_LOW     = 3'h4,
            REG_COUNTER_HIGH    = 3'h5,
            REG_ADJUST_LOW      = 3'h6,
            REG_ADJUST_HIGH     = 3'h7;

wire [2:0]      csr_addr    = csr_cmd_addr[4:2];

reg             enabled;

reg  [31:0]     freq_in;

reg  [63:32]    cnt_high;

reg             adj_en;
reg  [63:0]     adj_value;

always @(posedge clk) begin
    if(rst) begin
        enabled         <= 1'b0;
        freq_in         <= FREQ_IN;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        // write
        if(csr_addr == REG_CONTROL) begin
            enabled         <= csr_cmd_data[0];
        end
        if(csr_addr == REG_FREQUENCY) begin
            freq_in         <= csr_cmd_data;
        end
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
                REG_CONTROL:        csr_rsp_data[0]     <= enabled;
                REG_FREQUENCY:      csr_rsp_data        <= freq_in;
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
    .CNT_RATE       ( CNT_RATE ),
    .CNT_INC        ( CNT_INC ),
    .CNTB           ( 64 ),
    .DIVB           ( 33 ),
    .OUTPUTS        ( 8 ),
    .OUTPUT_DIV     ( OUTPUT_DIV )
) dlsc_timebase_core (
    .clk            ( clk ),
    .rst            ( rst_timebase ),
    .clk_en_out     ( clk_en_out ),
    .stopped        ( stopped ),
    .adjusting      ( adjusting ),
    .cnt            ( cnt ),
    .cnt_wrapped    (  ),
    .adj_en         ( adj_en ),
    .adj_value      ( adj_value ),
    .freq_in        ( {1'b0,freq_in} )
);


endmodule

