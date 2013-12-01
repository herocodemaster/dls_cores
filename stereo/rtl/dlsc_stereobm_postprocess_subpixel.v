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
// Implements a sub-pixel interpolation function that can be compatible
// with the implementation in OpenCV's findStereoCorrespondenceBM (the
// one in OpenCV 2.2.0; 2.1.0 is slightly different).
//
// Compatibility is only achieved when SUB_BITS = 4 and SUB_BITS_EXTRA = 4.
//
// The pipelined divider in this module is often a critical timing path;
// minimizing (SUB_BITS + SUB_BITS_EXTRA) reduces this path. Leaving
// SUB_BITS_EXTRA at 0 will only yield a deviation of +-1 LSbit relative to
// OpenCV (+-1/16th of a disparity).
//
// Code from the C reference model:
//
// if(disps[x] > 0 && disps[x] < (DISPARITIES-1)) {
//     int lo = sads_lo[x] - sads[x];
//     int hi = sads_hi[x] - sads[x];
//     if( lo != hi ) {
//         int t = (lo>hi) ? (lo-hi) : (hi-lo);
//         int b = (lo>hi) ?  lo     :  hi;
//         int d = (t<<(SUB_BITS+SUB_BITS_EXTRA-1))/b;
//         if(lo > hi) {
//             dptr[x] += (short)( (d + ((1<<SUB_BITS_EXTRA)-1)) >> SUB_BITS_EXTRA );
//         } else {
//             dptr[x] += (short)( (((1<<SUB_BITS_EXTRA)-1) - d) >> SUB_BITS_EXTRA );
//         }
//     }
// }

module dlsc_stereobm_postprocess_subpixel #(
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter SUB_BITS      = 4,
    parameter SUB_BITS_EXTRA= 4,
    parameter SAD_BITS      = 16,
    parameter OUT_CYCLE     = 3 + (SUB_BITS+SUB_BITS_EXTRA),
    // derived; don't touch
    parameter DISP_BITS_S   = (DISP_BITS+SUB_BITS)
) (
    // system
    input   wire                        clk,

    // inputs from disparity buffer
    input   wire    [DISP_BITS-1:0]     in_disp,
    input   wire    [ SAD_BITS-1:0]     in_sad,
    
    // additional inputs for sub-pixel approximation (SUB_BITS > 0)
    input   wire    [ SAD_BITS-1:0]     in_lo,
    input   wire    [ SAD_BITS-1:0]     in_hi,

    // output
    output  wire    [DISP_BITS_S-1:0]   out_disp
);

`include "dlsc_synthesis.vh"

localparam SUB_BITS_TOTAL   = SUB_BITS + SUB_BITS_EXTRA;
localparam SUB_OFFSET       = (2**SUB_BITS_EXTRA)-1;
localparam DISP_BITS_TOTAL  = (DISP_BITS + SUB_BITS_TOTAL);

// CD0 is cycle at output of divider;
// c2 is input; prop delay of SUB_BITS_TOTAL
localparam CYCLE_CD0 = 2 + SUB_BITS_TOTAL+1;
localparam CYCLE_CD1 = CYCLE_CD0 + 1;

`DLSC_NO_SHREG reg                c1_zero;    // subpixel adjustment is 0
`DLSC_NO_SHREG reg                c1_add;     // lo > hi
`DLSC_NO_SHREG reg [SAD_BITS-1:0] c1_lo;      // sad[disp-1] - sad[disp]
`DLSC_NO_SHREG reg [SAD_BITS-1:0] c1_hi;      // sad[disp+1] - sad[disp]

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    // check whether adjustment will be zero
    c1_zero     <= (in_disp == 0) || (in_disp == (DISPARITIES-1)) || (in_lo == in_hi);
    // determine adjustment direction
    c1_add      <= (in_lo > in_hi);
    // offset lo/hi to be relative to sad
    c1_lo       <= in_lo - in_sad;
    c1_hi       <= in_hi - in_sad;
end
/* verilator lint_on WIDTH */


// delay c1 to cd0
wire                    cd0_zero;
wire                    cd0_add;
dlsc_pipedelay #(
    .DATA       ( 2 ),
    .DELAY      ( CYCLE_CD0 - 1 )
) dlsc_pipedelay_inst_c1cd0 (
    .clk        ( clk ),
    .in_data    ( {  c1_zero,  c1_add } ),
    .out_data   ( { cd0_zero, cd0_add } )
);


`DLSC_NO_SHREG reg [SAD_BITS-1:0]           c2_t;
`DLSC_NO_SHREG reg [SAD_BITS-1:0]           c2_b;

always @(posedge clk) begin
    // get inputs to divider
    c2_t        <= c1_add ? (c1_lo - c1_hi) : (c1_hi - c1_lo);
    c2_b        <= c1_add ?  c1_lo          :  c1_hi;
end


// delay in_disp to cd0
wire [DISP_BITS-1:0]    cd0_disp;
dlsc_pipedelay #(
    .DATA       ( DISP_BITS ),
    .DELAY      ( CYCLE_CD0 )
) dlsc_pipedelay_inst_cd0 (
    .clk        ( clk ),
    .in_data    ( in_disp ),
    .out_data   ( cd0_disp )
);


// ** divider **
wire [SUB_BITS_TOTAL-1:0] cd0_res;

dlsc_divu #(
    .CYCLES     ( 1 ),
    .NB         ( SAD_BITS ),
    .DB         ( SAD_BITS ),
    .QB         ( SUB_BITS_TOTAL ),
    .QSKIP      ( SAD_BITS-1 )
) dlsc_divu_inst (
    .clk        ( clk ),
    .rst        ( 1'b0 ),
    .in_valid   ( 1'b1 ),
    .in_num     ( c2_t ),
    .in_den     ( c2_b ),
    .out_valid  (  ),
    .out_quo    ( cd0_res )
);


/* verilator lint_off WIDTH */
wire [SUB_BITS_TOTAL-1:0]  cd0_disp_offset  = SUB_OFFSET;
/* verilator lint_on WIDTH */

wire [DISP_BITS_TOTAL-1:0] cd0_disp_total   = { cd0_disp, cd0_disp_offset };
wire [DISP_BITS_TOTAL-1:0] cd0_res_total    = { {DISP_BITS{1'b0}} , cd0_res };
wire [DISP_BITS_TOTAL-1:0] cd1_disp_total   = cd0_add ? (cd0_disp_total + cd0_res_total) : (cd0_disp_total - cd0_res_total);

`DLSC_NO_SHREG reg [DISP_BITS_S-1:0] cd1_disp;

always @(posedge clk) begin
    if(cd0_zero) begin
        cd1_disp    <= { cd0_disp,{SUB_BITS{1'b0}} };
    end else begin
        cd1_disp    <= cd1_disp_total[DISP_BITS_TOTAL-1:SUB_BITS_EXTRA];
    end
end


// match output delay
dlsc_pipedelay #(
    .DATA       ( DISP_BITS_S ),
    .DELAY      ( OUT_CYCLE - CYCLE_CD1 )
) dlsc_pipedelay_inst_out (
    .clk        ( clk ),
    .in_data    ( cd1_disp ),
    .out_data   ( out_disp )
);

endmodule

