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
// Single capture channel for timer_capture module. Handles:
//  - input muxing
//  - event detection
//  - event counting
//  - event prescaling
//  - event time/state capture

module dlsc_timer_capture_channel #(
    parameter INDEX         = 0,                // channel index
    parameter INPUTS        = 1,                // number of event inputs (1-256)
    parameter IBITS         = 1,                // bits for INPUTS
    parameter CHANNELS      = 1,                // number of capture channels (1-16)
    parameter PBITS         = 4,                // bits for input prescaler (2-32)
    parameter EBITS         = 8,                // bits for event counter (2-31)
    parameter CSR_ADDR      = 32
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // master counter input
    input   wire    [63:0]          cnt,

    // event inputs
    input   wire    [INPUTS-1:0]    trigger,

    // master enable
    input   wire                    enabled,

    // channel state
    output  wire                    ch_out,     // this channel's state
    input   wire    [CHANNELS-1:0]  ch_in,      // all channels' state

    // FIFO interface
    input   wire                    fifo_ready,
    output  reg                     fifo_valid,
    output  reg     [63:0]          fifo_cnt,
    output  reg     [CHANNELS-1:0]  fifo_chstate,

    // Interrupt flag set
    output  reg                     set_event_overflow,
    output  reg                     set_lost_event,

    // register access
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // register read values
    output  wire    [31:0]          reg_source,
    output  wire    [31:0]          reg_prescaler,
    output  wire    [31:0]          reg_event
);


// Registers

/* verilator lint_off WIDTH */
localparam  REG_SOURCE      = 6'h10 + INDEX,
            REG_PRESCALER   = 6'h20 + INDEX,
            REG_EVENT       = 6'h30 + INDEX;
/* verilator lint_on WIDTH */

wire [5:0] csr_addr = csr_cmd_addr[7:2];

reg  [IBITS-1:0]    source_sel;
reg                 source_pos;
reg                 source_neg;
reg  [PBITS-1:0]    prescaler;
reg  [EBITS-1:0]    event_cnt;
reg                 event_overflow;

assign reg_source       = { 22'd0, source_neg, source_pos, {(8-IBITS){1'b0}}, source_sel };
assign reg_prescaler    = { {(32-PBITS){1'b0}}, prescaler };
assign reg_event        = { event_overflow, {(31-EBITS){1'b0}}, event_cnt };

always @(posedge clk) begin
    if(rst) begin
        source_sel  <= 0;
        source_pos  <= 1'b0;
        source_neg  <= 1'b0;
        prescaler   <= 0;
    end else if(csr_cmd_valid && csr_cmd_write) begin
/* verilator lint_off WIDTH */
        if(csr_addr == REG_SOURCE) begin
/* verilator lint_on WIDTH */
            source_sel  <= csr_cmd_data[IBITS-1:0];
            source_pos  <= csr_cmd_data[8];
            source_neg  <= csr_cmd_data[9];
        end
/* verilator lint_off WIDTH */
        if(csr_addr == REG_PRESCALER) begin
/* verilator lint_on WIDTH */
            prescaler   <= csr_cmd_data[PBITS-1:0];
        end
    end
end


// Channel mux

wire [(2**IBITS)-1:0] inputs = { {((2**IBITS)-INPUTS){1'b0}} , trigger };

reg in;
reg in_prev;

assign ch_out = in;

always @(posedge clk) begin
    if(rst) begin
        in      <= 1'b0;
        in_prev <= 1'b0;
    end else begin
        in      <= inputs[source_sel];
        in_prev <= in;
    end
end


// Event detect

wire in_event = ( in && !in_prev && source_pos) ||
                (!in &&  in_prev && source_neg);


// Event counter
// (not prescaled)

reg [EBITS-1:0] next_event_cnt;
reg             next_event_overflow;
reg             next_set_overflow;

always @* begin
    next_event_cnt      = event_cnt;
    next_event_overflow = event_overflow;
    next_set_overflow   = 1'b0;

/* verilator lint_off WIDTH */
    if(csr_cmd_valid && !csr_cmd_write && csr_addr == REG_EVENT) begin
/* verilator lint_on WIDTH */
        next_event_cnt      = 0;
        next_event_overflow = 1'b0;
    end

    if(in_event) begin
        {next_set_overflow,next_event_cnt} = {1'b0,next_event_cnt} + 1;
    end

    next_event_overflow = next_event_overflow || next_set_overflow;
end

always @(posedge clk) begin
    if(rst || !enabled) begin
        event_cnt           <= 0;
        event_overflow      <= 1'b0;
        set_event_overflow  <= 1'b0;
    end else begin
        event_cnt           <= next_event_cnt;
        event_overflow      <= next_event_overflow;
        set_event_overflow  <= next_set_overflow;
    end
end


// Prescaler

reg [PBITS-1:0] ps_cnt;
reg             ps_cnt_zero;

wire            ps_event    = in_event && ps_cnt_zero;

reg [PBITS-1:0] next_ps_cnt;

always @* begin
    next_ps_cnt     = ps_cnt;
    if(ps_event || !enabled) begin
        next_ps_cnt     = prescaler;
    end else if(in_event) begin
        next_ps_cnt     = ps_cnt - 1;
    end
end

always @(posedge clk) begin
    if(rst) begin
        ps_cnt      <= 0;
        ps_cnt_zero <= 1'b1;
    end else begin
        ps_cnt      <= next_ps_cnt;
        ps_cnt_zero <= (next_ps_cnt == 0);
    end
end


// Latch event

always @(posedge clk) begin
    if(rst || !enabled) begin
        fifo_valid      <= 1'b0;
        set_lost_event  <= 1'b0;
    end else begin
        set_lost_event  <= 1'b0;
        if(fifo_ready) begin
            fifo_valid      <= 1'b0;
        end
        if(ps_event) begin
            if(fifo_valid) begin
                set_lost_event  <= 1'b1;
            end else begin
                fifo_valid      <= 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    if(ps_event && !fifo_valid) begin
        fifo_cnt        <= cnt;
        fifo_chstate    <= ch_in;
    end
end


endmodule

