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
// Configuration sequencer.

module dlsc_config_enabler #(
    parameter DOMAINS       = 0,    // number of non-CSR clock domains to sequence
    parameter RESET_CYCLES  = 48,   // number of CSR clock cycles to hold reset
    // derived; don't touch
    parameter DOMAINS1      = (DOMAINS>0) ? DOMAINS : 1
) (
    // ** CSR Domain **

    // system
    input   wire                        csr_clk,
    input   wire                        csr_rst_in,         // reset for entire clock domain
    output  wire                        csr_rst_persist,    // reset for persistent pipeline logic; asserted when disabled (but not between each frame)
    output  wire                        csr_rst_config,     // reset for per-frame config logic; asserted between each frame (prior to config)
    output  wire                        csr_rst_frame,      // reset for per-frame pipeline logic; asserted between each frame (prior to and during config)

    // control
    input   wire                        csr_control_enable,

    // config handshake
    input   wire                        csr_config_valid,
    output  reg                         csr_config_ready,

    // status
    output  reg                         csr_status_enabled,

    // interrupt
    output  reg                         csr_set_disabled,
    output  reg                         csr_set_config_needed,
    output  reg                         csr_set_done,

    // feedback
    input   wire                        csr_frame_done,     // assert once frame has finished
    input   wire                        csr_config_done,    // assert once config has finished

    // ** Other Domains **

    // system
    input   wire    [DOMAINS1-1:0]      other_clk,
    input   wire    [DOMAINS1-1:0]      other_rst_in,
    output  wire    [DOMAINS1-1:0]      other_rst_persist,
    output  wire    [DOMAINS1-1:0]      other_rst_config,
    output  wire    [DOMAINS1-1:0]      other_rst_frame
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

genvar j;

localparam CNTB = `dlsc_clog2(RESET_CYCLES);

localparam  ST_DISABLING    = 3'd0, // disabling; holding all resets
            ST_DISABLED     = 3'd1, // disabled; ready for enable
            ST_CONFIG_RST   = 3'd2, // enabling; rst_persist released; holding other resets
            ST_CONFIG_WAIT  = 3'd3, // configuring; waiting for config_valid
            ST_CONFIG_RUN   = 3'd4, // configuring; waiting for config_done
            ST_FRAME_RST    = 3'd5, // configured; holding frame reset
            ST_FRAME_RUN    = 3'd6; // processing frame; waiting for frame_done

reg  [2:0]      st;

reg  [CNTB-1:0] cnt;
wire            cnt_last = (cnt == 0);

reg  [2:0]      next_st;
reg  [CNTB-1:0] next_cnt;
reg             next_config_ready;
reg             next_set_needed;
reg             next_set_disabled;
reg             next_set_done;
reg             next_status_enabled;
reg             next_enable_persist;
reg             next_enable_config;
reg             next_enable_frame;

always @* begin
    next_st             = st;
    next_cnt            = RESET_CYCLES-1;
    next_config_ready   = 1'b0;
    next_set_needed     = 1'b0;
    next_set_disabled   = 1'b0;
    next_set_done       = 1'b0;
    if(st == ST_DISABLING) begin
        // waiting for all resets to have been asserted for RESET_CYCLES
        if(!cnt_last) begin
            next_cnt = cnt - 1;
        end else begin
            next_st = ST_DISABLED;
        end
    end
    if(st == ST_DISABLED && csr_control_enable) begin
        // enable requested
        next_st = ST_CONFIG_RST;
    end
    if(st == ST_CONFIG_RST) begin
        // waiting for config and frame resets to have been asserted for RESET_CYCLES
        if(!cnt_last) begin
            next_cnt = cnt - 1;
        end else begin
            next_st = ST_CONFIG_WAIT;
        end
    end
    if(st == ST_CONFIG_WAIT) begin
        if(!csr_config_valid) begin
            // config needed
            next_set_needed = 1'b1;
        end else begin
            // config available
            next_st = ST_CONFIG_RUN;
        end
    end
    if(st == ST_CONFIG_RUN && csr_config_done) begin
        // config completed
        next_st = ST_FRAME_RST;
        next_config_ready = 1'b1;
    end
    if(st == ST_FRAME_RST) begin
        // waiting for frame reset to have been asserted for RESET_CYCLES
        if(!cnt_last) begin
            next_cnt = cnt - 1;
        end else begin
            next_st = ST_FRAME_RUN;
        end
    end
    if(st == ST_FRAME_RUN && csr_frame_done) begin
        // frame completed; prepare to configure for next frame
        next_st = ST_CONFIG_RST;
        next_set_done = 1'b1;
    end
    if(!csr_control_enable && !(st == ST_DISABLING || st == ST_DISABLED)) begin
        // disable requested
        next_st             = ST_DISABLING;
        next_cnt            = RESET_CYCLES-1;
        next_config_ready   = 1'b0;
        next_set_needed     = 1'b0;
        next_set_disabled   = 1'b1;
        next_set_done       = 1'b0;
    end
    // decoded outputs
    next_status_enabled = (next_st != ST_DISABLED);
    next_enable_persist = (next_st == ST_FRAME_RUN || next_st == ST_FRAME_RST || next_st == ST_CONFIG_RUN || next_st == ST_CONFIG_WAIT || next_st == ST_CONFIG_RST);
    next_enable_config  = (next_st == ST_FRAME_RUN || next_st == ST_FRAME_RST || next_st == ST_CONFIG_RUN);
    next_enable_frame   = (next_st == ST_FRAME_RUN);
end

`DLSC_PIPE_REG reg csr_enable_persist;
`DLSC_PIPE_REG reg csr_enable_config;
`DLSC_PIPE_REG reg csr_enable_frame;

always @(posedge csr_clk) begin
    if(csr_rst_in) begin
        st                  <= ST_DISABLING;
        cnt                 <= RESET_CYCLES-1;
        csr_enable_persist  <= 1'b0;
        csr_enable_config   <= 1'b0;
        csr_enable_frame    <= 1'b0;
        csr_config_ready    <= 1'b0;
        csr_status_enabled  <= 1'b0;
        csr_set_disabled    <= 1'b0;
        csr_set_config_needed <= 1'b0;
        csr_set_done        <= 1'b0;
    end else begin
        st                  <= next_st;
        cnt                 <= next_cnt;
        csr_enable_persist  <= next_enable_persist;
        csr_enable_config   <= next_enable_config;
        csr_enable_frame    <= next_enable_frame;
        csr_config_ready    <= next_config_ready;
        csr_status_enabled  <= next_status_enabled;
        csr_set_disabled    <= next_set_disabled;
        csr_set_config_needed <= next_set_needed;
        csr_set_done        <= next_set_done;
    end
end

// CSR reset outputs

`DLSC_FANOUT_REG reg csr_rst_persist_r  = 1'b1;
`DLSC_FANOUT_REG reg csr_rst_config_r   = 1'b1;
`DLSC_FANOUT_REG reg csr_rst_frame_r    = 1'b1;

always @(posedge csr_clk) begin
    if(csr_rst_in) begin
        csr_rst_frame_r     <= 1'b1;
        csr_rst_config_r    <= 1'b1;
        csr_rst_persist_r   <= 1'b1;
    end else begin
        csr_rst_frame_r     <= !csr_enable_frame;
        csr_rst_config_r    <= !csr_enable_config  && csr_rst_frame_r;  // config reset can only assert after frame reset
        csr_rst_persist_r   <= !csr_enable_persist && csr_rst_config_r; // persist reset can only assert after config reset
    end
end

assign csr_rst_persist  = csr_rst_persist_r;
assign csr_rst_config   = csr_rst_config_r;
assign csr_rst_frame    = csr_rst_frame_r;

// Other reset outputs

generate
for(j=0;j<DOMAINS;j=j+1) begin:GEN_DOMAINS

    wire clk    = other_clk[j];
    wire rst_in = other_rst_in[j];

    wire enable_persist;
    wire enable_config;
    wire enable_frame;

    dlsc_syncflop #(
        .DATA       ( 3 ),
        .RESET      ( 3'b00 )
    ) dlsc_syncflop (
        .in         ( { csr_enable_frame, csr_enable_config, csr_enable_persist } ),
        .clk        ( clk ),
        .rst        ( rst_in ),
        .out        ( {     enable_frame,     enable_config,     enable_persist } )
    );

    `DLSC_FANOUT_REG reg rst_persist_r  = 1'b1;
    `DLSC_FANOUT_REG reg rst_config_r   = 1'b1;
    `DLSC_FANOUT_REG reg rst_frame_r    = 1'b1;

    always @(posedge clk) begin
        if(rst_in) begin
            rst_frame_r     <= 1'b1;
            rst_config_r    <= 1'b1;
            rst_persist_r   <= 1'b1;
        end else begin
            rst_frame_r     <= !enable_frame;
            rst_config_r    <= !enable_config  && rst_frame_r;  // config reset can only assert after frame reset
            rst_persist_r   <= !enable_persist && rst_config_r; // persist reset can only assert after config reset
        end
    end

    assign other_rst_persist[j] = rst_persist_r;
    assign other_rst_config[j]  = rst_config_r;
    assign other_rst_frame[j]   = rst_frame_r;

end
if(DOMAINS<=0) begin:GEN_NO_DOMAINS

    assign other_rst_persist    = 1'bx;
    assign other_rst_config     = 1'bx;
    assign other_rst_frame      = 1'bx;

end
endgenerate

endmodule

