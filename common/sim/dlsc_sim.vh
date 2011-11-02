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


`ifdef DLSC_SIMULATION

// This file should be included in any module that wishes to use the various
// dlsc_ simulation macros. It should be included inside the module definition.
// In general, only testbench (non-synthesizable) code should include this.

`ifndef DLSC_SIM_INCLUDED
`define DLSC_SIM_INCLUDED

`ifdef VERILATOR

    // DLSC_DPI_PATH must point to top _tbwrapper which includes "dlsc_dpi.vh"
    // (trying to have DPI import in just one place to mitigate Verilator internal errors)
    `define dlsc_error  `DLSC_DPI_PATH.dlsc_dpi_error
    `define dlsc_warn   `DLSC_DPI_PATH.dlsc_dpi_warn
    `define dlsc_info   `DLSC_DPI_PATH.dlsc_dpi_info
    `define dlsc_verb   `DLSC_DPI_PATH.dlsc_dpi_verb
    `define dlsc_okay   `DLSC_DPI_PATH.dlsc_dpi_okay
    `define dlsc_assert `DLSC_DPI_PATH.dlsc_dpi_assert

`else

    `ifndef DLSC_DEBUG_WARN
        `define DLSC_DEBUG_WARN 0
    `endif
    `ifndef DLSC_DEBUG_INFO
        `define DLSC_DEBUG_INFO 0
    `endif
    `ifndef DLSC_DEBUG_VERB
        `define DLSC_DEBUG_VERB 0
    `endif
    `ifndef DLSC_DEBUG_OKAY
        `define DLSC_DEBUG_OKAY 0
    `endif

    // display macros, qualified by desired level of verbosity
    `define dlsc_display $write("%t: %m: ", $time); $display
    `define dlsc_warn `DLSC_TB._dlsc_warn; if(`DLSC_DEBUG_WARN) $write("%t : [%m] : WARN : ", $time); if(`DLSC_DEBUG_WARN) $display
    `define dlsc_info if(`DLSC_DEBUG_INFO) $write("%t : [%m] : INFO : ", $time); if(`DLSC_DEBUG_INFO) $display
    `define dlsc_verb if(`DLSC_DEBUG_VERB) $write("%t : [%m] : VERB : ", $time); if(`DLSC_DEBUG_VERB) $display

    // macros for recording success or failure of a test
    // (all invocations of these will be used for reporting final pass/fail when dlsc_finish is called)
    `define dlsc_okay `DLSC_TB._dlsc_okay; if(`DLSC_DEBUG_OKAY) $write("%t : [%m] : OKAY : ", $time); if(`DLSC_DEBUG_OKAY) $display
    `define dlsc_error `DLSC_TB._dlsc_error; $write("%t : [%m] : *** ERROR *** : ",$time); $display

    // if condition is true, invokes dlsc_okay; otherwise, invokes dlsc_error
    `define dlsc_assert(cond,msg) if(cond) begin `dlsc_okay(msg); end else begin `dlsc_error(msg); end if(0)

    // use instead of $finish (prints out pass/fail result, then finishes)
    `define dlsc_finish `DLSC_TB._dlsc_finish

    // generates random number in [min,max] range (inclusive)
    // (wrapper for $dist_uniform - initial seed specified with `RANDSEED)
    `define dlsc_rand(min,max) `DLSC_TB._dlsc_rand(min,max)

`endif // `ifndef VERILATOR

`endif // `ifndef DLSC_SIM_INCLUDED
`endif // `ifdef DLSC_SIMULATION

