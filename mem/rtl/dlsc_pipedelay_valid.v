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
// Wrapper for a common type of pipeline delay, in which 'data' is qualified by
// a 'valid' signal. 'valid' signals are resettable to 0, while 'data' signals
// are not reset ('data' will be delayed using efficient shift-registers).

module dlsc_pipedelay_valid #(
    parameter DATA      = 32,
    parameter DELAY     = 1
) (
    input   wire                clk,
    input   wire                rst,

    input   wire                in_valid,
    input   wire    [DATA-1:0]  in_data,

    output  wire                out_valid,
    output  wire    [DATA-1:0]  out_data
);

dlsc_pipedelay_rst #(
    .DATA       ( 1 ),
    .DELAY      ( DELAY ),
    .RESET      ( 1'b0 )
) dlsc_pipedelay_rst_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( in_valid ),
    .out_data   ( out_valid )
);

dlsc_pipedelay #(
    .DATA       ( DATA ),
    .DELAY      ( DELAY )
) dlsc_pipedelay_inst (
    .clk        ( clk ),
    .in_data    ( in_data ),
    .out_data   ( out_data )
);

endmodule
    
