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
// Single-slope PWM module.
//
// A single master counter sequences all internal PWM operations. This timer is
// incremented by a timebase selected by REG_TIMEBASE. Within a PWM cycle, the
// period of the master counter is determined by REG_PERIOD; it counts from 0
// to [REG_PERIOD-1] (inclusive).
//
// Each PWM channel has two compare registers - A and B. Compare A sets the PWM
// channel when it matches the master counter. Compare B clears the channel (and
// will override Compare A if both match simultaneously). The on-time for a PWM
// channel is equal to [REG_COMPARE_B - REG_COMPARE_A]. Each channel is always
// cleared at the beginning of a cycle (unless Compare A overrides this).
//
// These internal PWM channels may be masked off by REG_CHANNEL_ENABLE and
// inverted by REG_CHANNEL_INVERT prior to being output. If REG_CHANNEL_INVERT
// is set for a given channel, that channel will idle at 1 when disabled.
//
// Multiple consecutive PWM cycles are grouped into "shots". The number of
// cycles in a shot is set by REG_CYCLES_PER_SHOT. Each shot may be preceded
// by a delay set by REG_SHOT_DELAY. This delay may be disabled by setting it
// to 0.
//
// The PWM engine must be triggered before it starts running. An external
// trigger may be configured via the REG_TRIGGER register. Triggers can be edge
// or level-sensitive. The engine may also be manually triggered by writing 1
// to the Trigger flag in REG_FORCE.
//
// A single-shot mode is available (by setting Single-Shot in REG_CONTROL) that
// produces only one shot worth of cycles for each trigger event. Any edge-
// triggers that occur in the middle of a shot will be latched until the end of
// the shot, where it will immediately trigger another shot. Level-sensitive
// triggers are never latched.
//
// In continuous mode (single-shot disabled), the engine only requires one
// trigger event to start running. Once started, it can only be stopped by
// disabling the engine or switching to single-shot mode. Triggers are still
// latched and consumed (when present) as in single-shot mode, but the
// 'triggered' output will only assert once when the engine is first triggered.
// The Trigger-Lost flag will never be asserted in continuous mode.
//
// The PWM engine will only operate if the Enable flag is set in REG_CONTROL.
// Clearing this flag will immediately disable the engine and clear all PWM
// outputs to their inactive state (as set by REG_CHANNEL_INVERT).
//
// Clearing Enable in the middle of a cycle may produce runt pulses on the
// output. If this is not desired, it can be avoided by switching to single-shot
// mode and waiting for the final shot to complete before disabling the engine.
//
// All timing control registers (including REG_CYCLES_PER_SHOT, REG_SHOT_DELAY,
// REG_PERIOD, REG_COMPARE_A and REG_COMPARE_B) are shadowed. Writing to these
// registers will actually write to a bank of internal shadow registers, and
// will not immediately affect an ongoing PWM operation.
//
// To transfer the shadow registers to the active registers, write 1 to the
// Latch-Shadow flag in REG_FORCE. At the beginning of the next shot, this will
// cause the active registers to be atomically updated from the shadow
// registers.
//
// If the PWM engine is disabled, the shadow registers are transparent (they
// continuously update the active registers). If you configure the PWM engine
// before enabling it, and do not need to change configuration once enabled,
// then you do not need to worry about setting Latch-Shadow.
//

module dlsc_pwm #(
    // ** PWM **
    parameter BITS          = 16,               // bits for PWM counter (2-32)
    parameter SBITS         = 8,                // bits for Shot Cycle counter (2-32)
    parameter CHANNELS      = 1,                // number of PWM output channels (1-16)
    parameter TIMEBASES     = 1,                // number of external clock enables (1-256)
    parameter TRIGGERS      = 1,                // number of external event inputs (1-256)

    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_INSTANCE = 32'h00000000      // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // timebase input
    input   wire    [TIMEBASES-1:0] timebase_en,

    // trigger input
    input   wire    [TRIGGERS-1:0]  trigger,

    // PWM output
    output  reg     [CHANNELS-1:0]  pwm,

    // status
    output  wire                    enabled,    // PWM engine enabled (but may be waiting for trigger)
    output  reg                     triggered,  // PWM engine triggered
    output  reg                     active,     // PWM engine running

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

`include "dlsc_synthesis.vh"

localparam  CORE_MAGIC          = 32'he01ac7ca; // lower 32 bits of md5sum of "dlsc_pwm"
localparam  CORE_VERSION        = 32'h20120708;
localparam  CORE_INTERFACE      = 32'h20120708;

integer i;

// ** Registers **
//
// 0x04: Control (RW)
//  [0]     : enable
//  [1]     : single-shot
// 0x05: Force (RW; write 1 to set; self-clears when done)
//  [0]     : trigger
//  [1]     : latch shadowed config at beginning of next shot
// 0x06: Timebase (RW)
//  [7:0]   : external timebase source
//  [8]     : use internal (undivided) timebase
// 0x07: Trigger (RW)
//  [7:0]   : trigger source
//  [8]     : trigger on rising edge (or high level)
//  [9]     : trigger on falling edge (or low level)
//  [10]    : trigger is level sensitive
// 0x08: Channel enable (RW)
//  [15:0]  : enable channel
// 0x09: Channel polarity (RW)
//  [15:0]  : invert channel
// 0x0A: Cycles per shot (RW) (shadowed)
// 0x0B: Shot delay (RW) (shadowed)
// 0x0C: Cycle period (RW) (shadowed)
// 0x10: Interrupt flags (RW; write 1 to clear)
//  [0]     : triggered
//  [1]     : end of shot delay
//  [2]     : end of cycle
//  [3]     : end of shot
//  [4]     : lost external trigger
//  [5]     : latched config
// 0x11: Interrupt flag select (RW)
// 0x12: Channel flags (RW; write 1 to clear)
//  [15:0]  : compare A hit
//  [31:16] : compare B hit
// 0x13: Channel flag select (RW)
// 0x14: Channel state (RO)
//  [15:0]  : channel state (before inversion and enable masking)
// 0x15: Status (RO)
//  [0]     : active
//  [1]     : in shot delay
//  [2]     : in cycle
// 0x16: Count (RO)
// 0x17: Shot cycle (RO)
// 0x20: channel 0 compare A (WO) (shadowed)
// 0x21: channel 1 compare A (WO) (shadowed)
// ...
// 0x2F: channel 15 compare A (WO) (shadowed)
// 0x30: channel 0 compare B (WO) (shadowed)
// 0x31: channel 1 compare B (WO) (shadowed)
// ...
// 0x3F: channel 15 compare B (WO) (shadowed)

localparam  REG_CORE_MAGIC          = 6'h00,
            REG_CORE_VERSION        = 6'h01,
            REG_CORE_INTERFACE      = 6'h02,
            REG_CORE_INSTANCE       = 6'h03;

localparam  REG_CONTROL             = 6'h04,
            REG_FORCE               = 6'h05,
            REG_TIMEBASE            = 6'h06,
            REG_TRIGGER             = 6'h07,
            REG_CHANNEL_ENABLE      = 6'h08,
            REG_CHANNEL_INVERT      = 6'h09,
            REG_CYCLES_PER_SHOT     = 6'h0A,
            REG_SHOT_DELAY          = 6'h0B,
            REG_PERIOD              = 6'h0C,
            REG_INT_FLAGS           = 6'h10,
            REG_INT_SELECT          = 6'h11,
            REG_CHANNEL_FLAGS       = 6'h12,
            REG_CHANNEL_SELECT      = 6'h13,
            REG_CHANNEL_STATE       = 6'h14,
            REG_STATUS              = 6'h15,
            REG_COUNT               = 6'h16,
            REG_CYCLE               = 6'h17,
            REG_COMPARE_A           = 6'h20,
            REG_COMPARE_B           = 6'h30;

wire [5:0]          csr_addr        = csr_cmd_addr[7:2];


// ** basic registers **

`DLSC_FANOUT_REG reg enabled_r;
assign              enabled         = enabled_r;

reg                 single_shot;
wire [31:0]         csr_control     = {30'd0,single_shot,enabled_r};

reg  [7:0]          timebase_sel;
reg                 timebase_int;
wire [31:0]         csr_timebase    = {timebase_int,23'd0,timebase_sel};

reg  [7:0]          trig_sel;
reg                 trig_on_rise;
reg                 trig_on_fall;
reg                 trig_is_level;
wire [31:0]         csr_trigger     = {21'd0,trig_is_level,trig_on_fall,trig_on_rise,trig_sel};

reg  [CHANNELS-1:0] channel_enable;
reg  [CHANNELS-1:0] channel_invert;

wire                status_shot_delay;
wire                status_in_cycle;
wire [31:0]         csr_status      = {29'd0,status_in_cycle,status_shot_delay,active};

always @(posedge clk) begin
    if(rst) begin
        enabled_r       <= 1'b0;
        single_shot     <= 1'b0;
        timebase_sel    <= 0;
        timebase_int    <= 1'b1;
        trig_sel        <= 0;
        trig_on_rise    <= 1'b0;
        trig_on_fall    <= 1'b0;
        trig_is_level   <= 1'b0;
        channel_enable  <= 0;
        channel_invert  <= 0;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_CONTROL) begin
            enabled_r       <= csr_cmd_data[0];
            single_shot     <= csr_cmd_data[1];
        end
        if(csr_addr == REG_TIMEBASE) begin
            timebase_sel    <= csr_cmd_data[7:0];
            timebase_int    <= csr_cmd_data[31];
        end
        if(csr_addr == REG_TRIGGER) begin
            trig_sel        <= csr_cmd_data[7:0];
            trig_on_rise    <= csr_cmd_data[8];
            trig_on_fall    <= csr_cmd_data[9];
            trig_is_level   <= csr_cmd_data[10];
        end
        if(csr_addr == REG_CHANNEL_ENABLE) begin
            channel_enable  <= csr_cmd_data[CHANNELS-1:0];
        end
        if(csr_addr == REG_CHANNEL_INVERT) begin
            channel_invert  <= csr_cmd_data[CHANNELS-1:0];
        end
    end
end


// ** interrupts **

localparam INTB = 6;
reg  [INTB-1:0]     int_select;
reg  [INTB-1:0]     int_flags;
reg  [INTB-1:0]     next_int_flags;

reg                 set_triggered;
reg                 set_end_of_delay;
reg                 set_end_of_cycle;
reg                 set_end_of_shot;
reg                 set_lost_trigger;
wire                set_latched;

always @* begin
    next_int_flags  = int_flags;
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_FLAGS) begin
        next_int_flags  = next_int_flags & ~csr_cmd_data[INTB-1:0];
    end
    if(set_triggered)       next_int_flags[0] = 1'b1;
    if(set_end_of_delay)    next_int_flags[1] = 1'b1;
    if(set_end_of_cycle)    next_int_flags[2] = 1'b1;
    if(set_end_of_shot)     next_int_flags[3] = 1'b1;
    if(set_lost_trigger)    next_int_flags[4] = 1'b1;
    if(set_latched)         next_int_flags[5] = 1'b1;
end

reg  [CHANNELS-1:0] ch_a_select;
reg  [CHANNELS-1:0] ch_a_flags;
reg  [CHANNELS-1:0] next_ch_a_flags;
reg  [CHANNELS-1:0] ch_a_hit;

reg  [CHANNELS-1:0] ch_b_select;
reg  [CHANNELS-1:0] ch_b_flags;
reg  [CHANNELS-1:0] next_ch_b_flags;
reg  [CHANNELS-1:0] ch_b_hit;

wire [31:0]         csr_channel_flags   = { {(16-CHANNELS){1'b0}}, ch_a_flags,
                                            {(16-CHANNELS){1'b0}}, ch_b_flags };
wire [31:0]         csr_channel_select  = { {(16-CHANNELS){1'b0}}, ch_a_select,
                                            {(16-CHANNELS){1'b0}}, ch_b_select };

always @* begin
    next_ch_a_flags = ch_a_flags;
    next_ch_b_flags = ch_b_flags;
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_CHANNEL_FLAGS) begin
        next_ch_a_flags = next_ch_a_flags & ~csr_cmd_data[  0 +: CHANNELS ];
        next_ch_b_flags = next_ch_b_flags & ~csr_cmd_data[ 16 +: CHANNELS ];
    end
    next_ch_a_flags = next_ch_a_flags | ch_a_hit;
    next_ch_b_flags = next_ch_b_flags | ch_b_hit;
end

always @(posedge clk) begin
    if(rst) begin
        csr_int     <= 1'b0;
        int_select  <= 0;
        int_flags   <= 0;
        ch_a_select <= 0;
        ch_a_flags  <= 0;
        ch_b_select <= 0;
        ch_b_flags  <= 0;
    end else begin
        csr_int     <= |(int_flags  & int_select ) ||
                       |(ch_a_flags & ch_a_select) ||
                       |(ch_b_flags & ch_b_select);

        int_flags   <= next_int_flags;
        ch_a_flags  <= next_ch_a_flags;
        ch_b_flags  <= next_ch_b_flags;

        if(csr_cmd_valid && csr_cmd_write) begin
            if(csr_addr == REG_INT_SELECT) begin
                int_select  <= csr_cmd_data[INTB-1:0];
            end
            if(csr_addr == REG_CHANNEL_SELECT) begin
                ch_a_select <= csr_cmd_data[  0 +: CHANNELS ];
                ch_b_select <= csr_cmd_data[ 16 +: CHANNELS ];
            end
        end
    end
end


// ** shadowed registers **

// shadowed values

reg  [SBITS-1:0]    shdw_cycles;
reg  [BITS-1:0]     shdw_shot_delay;
reg  [BITS-1:0]     shdw_period;

reg  [BITS-1:0]     shdw_cmp_a [CHANNELS-1:0];
reg  [BITS-1:0]     shdw_cmp_b [CHANNELS-1:0];

always @(posedge clk) begin
    if(rst) begin
        shdw_cycles     <= 0;
        shdw_shot_delay <= 0;
        shdw_period     <= 0;
        for(i=0;i<CHANNELS;i=i+1) begin
            shdw_cmp_a[i]   <= 0;
            shdw_cmp_b[i]   <= 0;
        end
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_CYCLES_PER_SHOT) begin
            shdw_cycles     <= csr_cmd_data[SBITS-1:0];
        end
        if(csr_addr == REG_SHOT_DELAY) begin
            shdw_shot_delay <= csr_cmd_data[BITS-1:0];
        end
        if(csr_addr == REG_PERIOD) begin
            shdw_period     <= csr_cmd_data[BITS-1:0];
        end
/* verilator lint_off WIDTH */
        if(csr_addr[5:4] == REG_COMPARE_A[5:4] && csr_addr[3:0] < CHANNELS) begin
            shdw_cmp_a[csr_addr[3:0]] <= csr_cmd_data[BITS-1:0];
        end
        if(csr_addr[5:4] == REG_COMPARE_B[5:4] && csr_addr[3:0] < CHANNELS) begin
            shdw_cmp_b[csr_addr[3:0]] <= csr_cmd_data[BITS-1:0];
        end
/* verilator lint_on WIDTH */
    end
end

// current values

reg  [SBITS-1:0]    cycles;
reg  [BITS-1:0]     shot_delay;
reg  [BITS-1:0]     period;

reg  [BITS-1:0]     cmp_a [CHANNELS-1:0];
reg  [BITS-1:0]     cmp_b [CHANNELS-1:0];

// next values

reg  [SBITS-1:0]    next_cycles;
reg  [BITS-1:0]     next_shot_delay;
wire                next_shot_delay_zero = (next_shot_delay == 0);
reg  [BITS-1:0]     next_period;

reg  [BITS-1:0]     next_cmp_a [CHANNELS-1:0];
reg  [BITS-1:0]     next_cmp_b [CHANNELS-1:0];

reg                 latch_ready;
reg                 latch_valid;

assign              set_latched     = (latch_ready && latch_valid);

always @(posedge clk) begin
    if(!enabled || (latch_ready && latch_valid)) begin
        cycles      <= next_cycles;
        shot_delay  <= next_shot_delay;
        period      <= next_period;
        for(i=0;i<CHANNELS;i=i+1) begin
            cmp_a[i]    <= next_cmp_a[i];
            cmp_b[i]    <= next_cmp_b[i];
        end
    end
end


// ** shadow latching **

always @* begin
    if(!enabled || latch_valid) begin
        next_cycles     = shdw_cycles;
        next_shot_delay = shdw_shot_delay;
        next_period     = shdw_period;
    end else begin
        next_cycles     = cycles;
        next_shot_delay = shot_delay;
        next_period     = period;
    end
    for(i=0;i<CHANNELS;i=i+1) begin
        if(!enabled || latch_valid) begin
            next_cmp_a[i]   = shdw_cmp_a[i];
            next_cmp_b[i]   = shdw_cmp_b[i];
        end else begin
            next_cmp_a[i]   = cmp_a[i];
            next_cmp_b[i]   = cmp_b[i];
        end
    end
end

always @(posedge clk) begin
    if(rst || !enabled) begin
        latch_valid     <= 1'b0;
    end else begin
        if(latch_ready) begin
            latch_valid     <= 1'b0;
        end
        if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_FORCE && csr_cmd_data[1]) begin
            latch_valid     <= 1'b1;
        end
    end
end


// ** clock enable mux **

wire    [255:0]     clk_en_mux      = { {(256-TIMEBASES){1'b0}} , timebase_en };
reg                 clk_en_pre;
`DLSC_FANOUT_REG reg clk_en;

always @(posedge clk) begin
    if(rst) begin
        clk_en      <= 1'b0;
        clk_en_pre  <= 1'b0;
    end else begin
        clk_en      <= clk_en_pre;
        clk_en_pre  <= timebase_int ? 1'b1 : clk_en_mux[timebase_sel];
    end
end


// ** triggering **

wire    [255:0]     trig_mux        = { {(256-TRIGGERS){1'b0}} , trigger };

reg                 trig_in;
reg                 trig_in_prev;

always @(posedge clk) begin
    trig_in_prev    <= trig_in;
    trig_in         <= trig_mux[trig_sel];
end

wire                trig_in_event   = ((trig_on_rise &&  trig_in && (!trig_in_prev || trig_is_level)) ||
                                       (trig_on_fall && !trig_in && ( trig_in_prev || trig_is_level)) );

reg                 csr_trig_event;

reg                 trig_ext_valid;
reg                 trig_csr_valid;

reg                 next_trig_ext_valid;
reg                 next_trig_csr_valid;

reg                 trigger_ready;
wire                trigger_valid   = trig_ext_valid || trig_csr_valid;

always @* begin
    set_lost_trigger    = 1'b0;
    next_trig_ext_valid = trig_ext_valid && !trigger_ready;
    next_trig_csr_valid = trig_csr_valid && !trigger_ready;

    if(trig_is_level) begin
        // can't lose external triggers when level-sensitive
        set_lost_trigger    = 1'b0;
        // level-sensitive is just passed through; not latched
        next_trig_ext_valid = trig_in_event;
    end else if(trig_in_event) begin
        // lost if trig was already latched
        set_lost_trigger    = next_trig_ext_valid || next_trig_csr_valid;
        next_trig_ext_valid = 1'b1;
    end

    if(csr_trig_event) begin
        // lost if trig was already latched/asserted
        set_lost_trigger    = next_trig_ext_valid || next_trig_csr_valid;
        next_trig_csr_valid = 1'b1;
    end

    if(!(enabled && single_shot)) begin
        // can't lose triggers unless enabled and in single-shot mode
        set_lost_trigger    = 1'b0;
    end
end

always @(posedge clk) begin
    if(rst || !enabled) begin
        trig_ext_valid  <= 1'b0;
        trig_csr_valid  <= 1'b0;
        csr_trig_event  <= 1'b0;
    end else begin
        trig_ext_valid  <= next_trig_ext_valid;
        trig_csr_valid  <= next_trig_csr_valid;
        csr_trig_event  <= (csr_cmd_valid && csr_cmd_write && csr_addr == REG_FORCE && csr_cmd_data[0]);
    end
end


// ** register read **

wire [31:0]         csr_force       = { 30'd0, latch_valid, trigger_valid };

wire [31:0]         csr_channel_state;

reg  [BITS-1:0]     cnt;
reg  [SBITS-1:0]    cycle;

always @(posedge clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:         csr_rsp_data                <= CORE_MAGIC;
                REG_CORE_VERSION:       csr_rsp_data                <= CORE_VERSION;
                REG_CORE_INTERFACE:     csr_rsp_data                <= CORE_INTERFACE;
                REG_CORE_INSTANCE:      csr_rsp_data                <= CORE_INSTANCE;
                REG_CONTROL:            csr_rsp_data                <= csr_control;
                REG_FORCE:              csr_rsp_data                <= csr_force;
                REG_TIMEBASE:           csr_rsp_data                <= csr_timebase;
                REG_TRIGGER:            csr_rsp_data                <= csr_trigger;
                REG_CHANNEL_ENABLE:     csr_rsp_data[CHANNELS-1:0]  <= channel_enable;
                REG_CHANNEL_INVERT:     csr_rsp_data[CHANNELS-1:0]  <= channel_invert;
                REG_INT_FLAGS:          csr_rsp_data[INTB-1:0]      <= int_flags;
                REG_INT_SELECT:         csr_rsp_data[INTB-1:0]      <= int_select;
                REG_CHANNEL_FLAGS:      csr_rsp_data                <= csr_channel_flags;
                REG_CHANNEL_SELECT:     csr_rsp_data                <= csr_channel_select;
                REG_CHANNEL_STATE:      csr_rsp_data                <= csr_channel_state;
                REG_STATUS:             csr_rsp_data                <= csr_status;
                REG_COUNT:              csr_rsp_data[BITS-1:0]      <= cnt;
                REG_CYCLE:              csr_rsp_data[SBITS-1:0]     <= cycle;
                // shadowed registers read current values (not shadow values)
                REG_CYCLES_PER_SHOT:    csr_rsp_data[SBITS-1:0]     <= cycles;
                REG_SHOT_DELAY:         csr_rsp_data[BITS-1:0]      <= shot_delay;
                REG_PERIOD:             csr_rsp_data[BITS-1:0]      <= period;
                // no provision to read compare values 
                default:                csr_rsp_data                <= 0;
            endcase
        end
    end
end


// ** master counter **

localparam  ST_IDLE         = 2'd0,
            ST_DELAY        = 2'd1,
            ST_RUN          = 2'd2;

reg  [1:0]          st;
reg  [1:0]          next_st;

assign              status_shot_delay = (st == ST_DELAY);
assign              status_in_cycle = (st == ST_RUN);

reg  [BITS-1:0]     next_cnt;

wire [BITS-1:0]     cnt_top         = (st == ST_DELAY) ? shot_delay : period;
wire                cnt_last        = ((cnt + {{(BITS-1){1'b0}},1'b1} ) == cnt_top);
wire                cnt_first       = (cnt == 0);

reg  [SBITS-1:0]    next_cycle;
wire                cycle_last      = ((cycle + {{(SBITS-1){1'b0}},1'b1} ) == cycles);

always @* begin

    next_st             = st;
    next_cnt            = cnt;
    next_cycle          = cycle;

    trigger_ready       = 1'b0;
    latch_ready         = 1'b0;

    set_triggered       = 1'b0;
    set_end_of_delay    = 1'b0;
    set_end_of_cycle    = 1'b0;
    set_end_of_shot     = 1'b0;

    if(enabled && clk_en) begin
        next_cnt            = cnt + 1;
        if(st == ST_IDLE) begin
            next_cnt            = 0;
            next_cycle          = 0;
            if(trigger_valid) begin
                // got trigger
                set_triggered       = 1'b1;
                trigger_ready       = 1'b1;
                latch_ready         = 1'b1;
                next_st             = next_shot_delay_zero ? ST_RUN : ST_DELAY;
            end
        end
        if(st == ST_DELAY && cnt_last) begin
            // finished shot delay
            set_end_of_delay    = 1'b1;
            next_cnt            = 0;
            next_cycle          = 0;
            next_st             = ST_RUN;
        end
        if(st == ST_RUN && cnt_last) begin
            // finished cycle
            set_end_of_cycle    = 1'b1;
            next_cnt            = 0;
            next_cycle          = cycle + 1;
            if(cycle_last) begin
                // finished shot
                set_end_of_shot     = 1'b1;
                next_cycle          = 0;
                if(!single_shot || trigger_valid) begin
                    // re-triggered
                    set_triggered       = single_shot;
                    trigger_ready       = 1'b1;
                    latch_ready         = 1'b1;
                    next_st             = next_shot_delay_zero ? ST_RUN : ST_DELAY;
                end else begin
                    // wait for trigger
                    next_st             = ST_IDLE;
                end
            end
        end
    end

end

always @(posedge clk) begin
    if(rst || !enabled) begin
        st          <= ST_IDLE;
        cnt         <= 0;
        cycle       <= 0;
    end else begin
        st          <= next_st;
        cnt         <= next_cnt;
        cycle       <= next_cycle;
    end
end

// delay status flags to match PWM output
// (output of state machine is c0)
`DLSC_FANOUT_REG reg c0_clk_en;
reg         c0_triggered;
reg         c1_triggered;
reg         c1_active;

always @(posedge clk) begin
    if(rst || !enabled) begin
        c0_clk_en       <= 1'b0;
        c0_triggered    <= 1'b0;
        c1_triggered    <= 1'b0;
        triggered       <= 1'b0;
        c1_active       <= 1'b0;
        active          <= 1'b0;
    end else begin
        c0_clk_en       <= clk_en;
        {triggered,c1_triggered,c0_triggered} <= {c1_triggered,c0_triggered,set_triggered};
        {active,c1_active} <= {c1_active,(st!=ST_IDLE)};
    end
end


// ** channels **

reg  [CHANNELS-1:0] ch;
reg  [CHANNELS-1:0] next_ch;

assign              csr_channel_state   = { {(32-CHANNELS){1'b0}} , ch };

always @* begin
    next_ch     = ch;
    ch_a_hit    = 0;
    ch_b_hit    = 0;

    if(c0_clk_en) begin
        if(st == ST_RUN) begin
            for(i=0;i<CHANNELS;i=i+1) begin
                ch_a_hit[i] = (cnt == cmp_a[i]);
                ch_b_hit[i] = (cnt == cmp_b[i]);
                
                if(cnt_first)   next_ch[i]  = 1'b0; // always clear at beginning of cycle
                if(ch_a_hit[i]) next_ch[i]  = 1'b1; // set on compare A
                if(ch_b_hit[i]) next_ch[i]  = 1'b0; // clear on compare B (highest priority)
            end
        end else begin
            // always clear when not running
            next_ch     = 0;
        end
    end
end

always @(posedge clk) begin
    if(rst || !enabled) begin
        ch      <= 0;
    end else begin
        ch      <= next_ch;
    end
end

always @(posedge clk) begin
    pwm     <= channel_invert ^ (channel_enable & ch);
end


endmodule

