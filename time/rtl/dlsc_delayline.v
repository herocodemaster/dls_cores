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
// Programmable delay-line.

module dlsc_delayline #(
    // ** Delay Line **
    parameter DATA              = 1,                    // width of data to be delayed
    parameter CHANNELS          = 1,                    // channels to subject to same delay (1-32)
    parameter TIMEBASES         = 1,                    // number of possible timebase clk_en sources
    parameter DELAY             = 32,                   // maximum delay
    parameter INERTIAL          = (DELAY>128),          // use inertial rather than transport delay
    
    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_INSTANCE     = 32'h00000000          // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // timebase
    input   wire    [TIMEBASES-1:0] timebase_en,

    // inputs
    input   wire    [(CHANNELS*DATA)-1:0] in_data,

    // delayed outputs
    output  wire    [(CHANNELS*DATA)-1:0] out_data,

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

`include "dlsc_clog2.vh"

genvar j;

localparam  TB                  = `dlsc_clog2(TIMEBASES);   // bits to select timebase
localparam  DB                  = `dlsc_clog2(DELAY);       // bits to select delay

localparam  CORE_MAGIC          = 32'h99d0903d;             // lower 32 bits of md5sum of "dlsc_delayline"
localparam  CORE_VERSION        = 32'h20120701;
localparam  CORE_INTERFACE      = 32'h20120701;

// ** Registers **
// 0x4: Timebase select (RW)
// 0x5: Channel bypass (RW)
// 0x6: Target delay (RW)
// 0x7: Current delay (RO)

localparam  REG_CORE_MAGIC      = 3'h0,
            REG_CORE_VERSION    = 3'h1,
            REG_CORE_INTERFACE  = 3'h2,
            REG_CORE_INSTANCE   = 3'h3;

localparam  REG_TIMEBASE        = 3'h4,
            REG_BYPASS          = 3'h5,
            REG_DELAY_TARGET    = 3'h6,
            REG_DELAY_CURRENT   = 3'h7;

wire [2:0]      csr_addr        = csr_cmd_addr[4:2];


reg  [TB-1:0]   timebase_sel;
reg  [CHANNELS-1:0] channel_bypass;
reg  [DB-1:0]   delay_target;
reg  [DB-1:0]   delay_current;

// ** register write **

always @(posedge clk) begin
    if(rst) begin
        timebase_sel    <= 0;
        channel_bypass  <= {CHANNELS{1'b1}};
        delay_target    <= 0;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_TIMEBASE) begin
            timebase_sel    <= csr_cmd_data[TB-1:0];
        end
        if(csr_addr == REG_BYPASS) begin
            channel_bypass  <= csr_cmd_data[CHANNELS-1:0];
        end
        if(csr_addr == REG_DELAY_TARGET) begin  
            delay_target    <= csr_cmd_data[DB-1:0];
        end
    end
end

// ** register read **

always @(posedge clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data                <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data                <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data                <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data                <= CORE_INSTANCE;
                REG_TIMEBASE:       csr_rsp_data[TB-1:0]        <= timebase_sel;
                REG_BYPASS:         csr_rsp_data[CHANNELS-1:0]  <= channel_bypass;
                REG_DELAY_TARGET:   csr_rsp_data[DB-1:0]        <= delay_target;
                REG_DELAY_CURRENT:  csr_rsp_data[DB-1:0]        <= delay_current;
                default:            csr_rsp_data                <= 0;
            endcase
        end
    end
end

// ** timebase mux **

wire [(2**TB)-1:0] timebase_mux = { {((2**TB)-TIMEBASES){1'b0}} , timebase_en };

reg             clk_en;

always @(posedge clk) begin
    if(rst) begin
        clk_en  <= 1'b0;
    end else begin
        clk_en  <= timebase_mux[timebase_sel];
    end
end

// ** delay update **

always @(posedge clk) begin
    if(rst) begin
        delay_current   <= 0;
    end else if(clk_en && delay_current != delay_target) begin
        if(delay_target > delay_current) begin
            delay_current   <= delay_current + 1;
        end else begin
            delay_current   <= delay_current - 1;
        end
    end
end

// ** channels **

generate
for(j=0;j<CHANNELS;j=j+1) begin:GEN_CHANNELS

    dlsc_delayline_channel #(
        .DATA       ( DATA ),
        .INERTIAL   ( INERTIAL ),
        .DELAY      ( DELAY ),
        .DB         ( DB )
    ) dlsc_delayline_channel (
        .clk        ( clk ),
        .clk_en     ( clk_en ),
        .cfg_bypass ( channel_bypass[j] ),
        .cfg_delay  ( delay_current ),
        .in_data    ( in_data [ j*DATA +: DATA ] ),
        .out_data   ( out_data[ j*DATA +: DATA ] )
    );

end
endgenerate


endmodule

