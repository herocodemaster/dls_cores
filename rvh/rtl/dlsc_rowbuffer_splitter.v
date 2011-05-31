// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
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
// An asynchronous FIFO with ready/valid handshaking for use on interfaces that
// are row/block-oriented (e.g. image processing). Can input a single row at a
// time, and split them into multiple parallel output ROWS.

module dlsc_rowbuffer_splitter #(
    parameter ROW_WIDTH = 20,           // width of each input row (ROW_WIDTH >= 16)
    parameter BUF_DEPTH = ROW_WIDTH,    // depth of buffer (BUF_DEPTH >= ROW_WIDTH)
    parameter ROWS      = 3,            // number of rows to output in parallel
    parameter DATA      = 16,           // width of each piece of data
    // derived; don't touch
    parameter DATA_R    = (DATA*ROWS)
) (

    // ** input **

    // system
    input   wire                    in_clk,
    input   wire                    in_rst,

    // handshake
    output  reg                     in_ready,
    input   wire                    in_valid,

    // data
    input   wire    [DATA  -1:0]    in_data,


    // ** output **

    // system
    input   wire                    out_clk,
    input   wire                    out_rst,

    // handshake
    input   wire                    out_ready,
    output  wire                    out_valid,

    // data
    output  wire    [DATA_R-1:0]    out_data

);

`include "dlsc_clog2.vh"

localparam ADDR = `dlsc_clog2(BUF_DEPTH);


// ** input **

// output status synchronized to input domain
wire [ADDR-1:0]     in_o_addr;
wire                in_o_phase;

// input status
reg  [ADDR-1:0]     in_addr;
reg  [ADDR-1:0]     in_addr_next;
reg                 in_addr_next_last;  // in_addr_next == (BUF_DEPTH-1)
reg                 in_phase;
reg                 in_phase_next;
reg  [ADDR-1:0]     in_addr_base;
reg                 in_addr_base_last;
reg                 in_phase_base;
reg  [ADDR-1:0]     in_cnt;
reg                 in_cnt_last;        // in_cnt == (ROW_WIDTH-1)
reg                 in_cnt_next_last;   // in_cnt == (ROW_WIDTH-2)
reg  [ROWS  :0]     in_row;             // 1 more than needed, for ROWS=1 case
wire                in_row_last = in_row[ROWS-1];

wire in_en = (in_ready && in_valid);

/* verilator lint_off WIDTH */
always @(posedge in_clk) begin
    if(in_rst) begin

        in_addr             <= 0;
        in_addr_next        <= 1;
        in_addr_next_last   <= 1'b0;
        in_phase            <= 1'b0;
        in_phase_next       <= 1'b0;
        in_addr_base        <= 0;
        in_addr_base_last   <= 1'b0;
        in_phase_base       <= 1'b0;
        in_cnt              <= 0;
        in_cnt_last         <= 1'b0;
        in_cnt_next_last    <= 1'b0;
        in_row              <= 1;

    end else if(in_en) begin

        // increment count
        in_cnt_next_last    <= (in_cnt == (ROW_WIDTH-3));
        in_cnt_last         <= in_cnt_next_last;
        if(in_cnt_last) begin
            in_cnt              <= 0;
        end else begin
            in_cnt              <= in_cnt + 1;
        end

        // shift row
        if(in_cnt_last) begin
            in_row              <= { in_row[ROWS-1:0], in_row_last };
        end            

        // increment address
        in_addr             <= in_addr_next;
        in_phase            <= in_phase_next;

        // increment next-address
        in_addr_next_last   <= (in_addr_next == (BUF_DEPTH-2));
        if(in_addr_next_last) begin
            in_addr_next        <= 0;
            in_phase_next       <= !in_phase_next;
        end else begin
            in_addr_next        <= in_addr_next + 1;
        end

        // set next-address for upcoming count overflow
        // (overrides increment operation above)
        if(!in_row_last && in_cnt_next_last) begin
            // continuing pass; must start row from same address as previous rows
            in_addr_next_last   <= in_addr_base_last;
            in_addr_next        <= in_addr_base;
            in_phase_next       <= in_phase_base;
        end

        // save base on final count overflow
        if(in_row_last && in_cnt_last) begin
            // starting new pass; can start row after end of previous row
            in_addr_base_last   <= in_addr_next_last;
            in_addr_base        <= in_addr_next;
            in_phase_base       <= in_phase_next;
        end

    end
end
/* verilator lint_on WIDTH */

always @(posedge in_clk) begin
    if(in_rst) begin
        in_ready        <= 1'b0;
    end else begin
        // if we're on the same phase, output is waiting on us, so we can write freely
        // if not, we must wait for output to consume data before we overwrite it
        if(in_en) begin
            in_ready        <= (in_phase_next == in_o_phase || in_addr_next != in_o_addr);
        end else begin
            in_ready        <= (in_phase      == in_o_phase || in_addr      != in_o_addr);
        end
    end
end

// address/phase to report to output domain..
// as far as the output domain is concerned, we never advance beyond the first
// datum until we're on the final row
reg  [ADDR-1:0]     in_i_addr;
reg                 in_i_phase;

always @(posedge in_clk) begin
    in_i_addr   <= in_row_last ?  in_addr :  in_addr_base;
    in_i_phase  <= in_row_last ? in_phase : in_phase_base;
end


// ** output **

// input status synchronized to output domain
wire [ADDR-1:0]     out_i_addr;
wire                out_i_phase;

// output status
reg  [ADDR-1:0]     out_addr;
reg  [ADDR-1:0]     out_addr_next;
reg                 out_addr_next_last; // out_addr_next == (BUF_DEPTH-1)
reg                 out_phase;
reg                 out_phase_next;

// handshake to rvh_decoupler
wire d_out_ready;
reg  d_out_valid;

wire out_en = (d_out_ready && d_out_valid);

/* verilator lint_off WIDTH */
always @(posedge out_clk) begin
    if(out_rst) begin

        out_addr            <= 0;
        out_addr_next       <= 1;
        out_addr_next_last  <= 1'b0;
        out_phase           <= 1'b0;
        out_phase_next      <= 1'b0;

    end else if(out_en) begin

        // increment address
        out_addr            <= out_addr_next;
        out_phase           <= out_phase_next;

        // increment next-address
        out_addr_next_last  <= (out_addr_next == (BUF_DEPTH-2));
        if(out_addr_next_last) begin
            out_addr_next       <= 0;
            out_phase_next      <= !out_phase_next;
        end else begin
            out_addr_next       <= out_addr_next + 1;
        end

    end
end
/* verilator lint_on WIDTH */

always @(posedge out_clk) begin
    if(out_rst) begin
        d_out_valid     <= 1'b0;
    end else begin
        // if we're on a different phase, input is waiting for us to consume data, so we're free to read
        // if not, we must wait for input to write data
        d_out_valid     <= out_en ? ( out_phase_next != out_i_phase || out_addr_next != out_i_addr ) :
                                    ( out_phase      != out_i_phase || out_addr      != out_i_addr );
    end
end


// ** synchronizers **

dlsc_domaincross #(
    .DATA       ( ADDR + 1 )
) dlsc_domaincross_inst_in (
    .in_clk     ( out_clk ),
    .in_data    ( {  out_addr,  out_phase } ),
    .out_clk    ( in_clk ),
    .out_data   ( { in_o_addr, in_o_phase } )
);

dlsc_domaincross #(
    .DATA       ( ADDR + 1 )
) dlsc_domaincross_inst_out (
    .in_clk     ( in_clk ),
    .in_data    ( {  in_i_addr,  in_i_phase } ),
    .out_clk    ( out_clk ),
    .out_data   ( { out_i_addr, out_i_phase } )
);


// ** buffers **

wire [DATA_R-1:0] d_out_data;

generate
    genvar j;
    for(j=0;j<ROWS;j=j+1) begin:GEN_BUFFERS

        dlsc_ram_dp #(
            .DATA           ( DATA ),
            .ADDR           ( ADDR ),
            .DEPTH          ( BUF_DEPTH ),
            .PIPELINE_WR    ( 1 ),
            .PIPELINE_WR_DATA ( 1 ),
            .PIPELINE_RD    ( 1 ),
            .WARNINGS       ( 0 )
        ) dlsc_ram_dp_inst (
            .write_clk      ( in_clk ),
            .write_en       ( in_en && in_row[j] ),
            .write_addr     ( in_addr ),
            .write_data     ( in_data ),
            .read_clk       ( out_clk ),
            .read_en        ( !d_out_valid || d_out_ready ),
            .read_addr      ( out_en ? out_addr_next : out_addr ),
            .read_data      ( d_out_data[ (j*DATA) +: DATA ] )
        );

    end
endgenerate


// ** output decoupler **

dlsc_rvh_decoupler #(
    .WIDTH          ( DATA_R )
) dlsc_rvh_decoupler_inst (
    .clk            ( out_clk ),
    .rst            ( out_rst ),
    .in_en          ( 1'b1 ),
    .in_ready       ( d_out_ready ),
    .in_valid       ( d_out_valid ),
    .in_data        ( d_out_data ),
    .out_en         ( 1'b1 ),
    .out_ready      ( out_ready ),
    .out_valid      ( out_valid ),
    .out_data       ( out_data )
);


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg in_rst_prev = 0;
always @(posedge in_clk) begin
    in_rst_prev <= in_rst;
    if(!in_rst && in_rst_prev) begin
        if(in_o_addr != 0 || in_o_phase != 0) begin
            `dlsc_warn("in_rst deasserted with synchronized out_* values not in reset state (reset pulse may have been too short)");
        end
    end
end

reg out_rst_prev = 0;
always @(posedge out_clk) begin
    out_rst_prev <= out_rst;
    if(!out_rst && out_rst_prev) begin
        if(out_i_addr != 0 || out_i_phase != 0) begin
            `dlsc_warn("out_rst deasserted with synchronized in_* values not in reset state (reset pulse may have been too short)");
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

