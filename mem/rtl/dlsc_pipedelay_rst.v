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
//
// Implements an arbitrary pipeline delay with resettable contents.
// This module supports three different reset modes, selected by FAST_RESET.
// In all modes, 'out_data' is always driven to RESET 1 cycle after 'rst' is
// asserted. The modes differ in their requirements regarding the 'rst' and
// 'in_data' input signals.
//
// FAST_RESET = 1:
//      Module can accept a 'rst' pulse that is only 1 cycle long. In this mode,
//      the module does NOT infer shift-registers in most FPGAs.
// FAST_RESET = 0:
//      'rst' must be held asserted for at least 33 cycles. 'in_data' does not
//      have to be driven to a specific value while 'rst' is asserted.
// FAST_RESET = -1:
//      When 'rst' is asserted, 'in_data' must also be driven to RESET. 'rst' must
//      be held asserted for at least 33 cycles after 'in_data' is driven to RESET.
//      These requirements are not always easy to meet, so this mode is generally
//      reserved for special low-level applications.
//

module dlsc_pipedelay_rst #(
    parameter DELAY         = 1,            // delay from input to output
    parameter DATA          = 1,            // width of delayed data
    parameter RESET         = {DATA{1'b0}}, // reset value for data
    parameter FAST_RESET    = 1             // when set, indicates that a single-cycle rst is expected
) (
    input   wire                clk,
    input   wire                rst,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

dlsc_pipedelay_rst_clken #(
    .DELAY      ( DELAY ),
    .DATA       ( DATA ),
    .RESET      ( RESET ),
    .FAST_RESET ( FAST_RESET )
) dlsc_pipedelay_rst_clken (
    .clk        ( clk ),
    .clk_en     ( 1'b1 ),
    .rst        ( rst ),
    .in_data    ( in_data ),
    .out_data   ( out_data )
);

endmodule

