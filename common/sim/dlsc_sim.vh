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

// TODO: add support for simulators other than Verilator

// This file should be included in any module that wishes to use the various
// dlsc_ simulation macros. It should be included inside the module definition.
// In general, only testbench (non-synthesizable) code should include this.

//`ifndef DLSC_COMMON_INCLUDED
//`define DLSC_COMMON_INCLUDED

// these defines determine what messages are actually printed
// they must be defined, but can optionally be overriden externally
`ifndef DEBUG_WARN
    `define DEBUG_WARN 1
`endif
`ifndef DEBUG_INFO
    `define DEBUG_INFO 1
`endif
`ifndef DEBUG_VERB
    `define DEBUG_VERB 1
`endif
`ifndef DEBUG_OKAY
    `define DEBUG_OKAY 0
`endif

import "DPI-C" function void dlsc_dpi_write(input string str /*verilator sformat*/ );
import "DPI-C" function void dlsc_dpi_display(input string str /*verilator sformat*/ );
import "DPI-C" function void dlsc_dpi_okay ();
import "DPI-C" function void dlsc_dpi_warn ();
import "DPI-C" function void dlsc_dpi_error ();

// display macros, qualified by desired level of verbosity
`define dlsc_display dlsc_dpi_write(" : [%m] : "); dlsc_dpi_display
`define dlsc_warn dlsc_dpi_warn; if(`DEBUG_WARN) dlsc_dpi_write(" : [%m] : WARN : "); if(`DEBUG_WARN) dlsc_dpi_display
`define dlsc_info if(`DEBUG_INFO) dlsc_dpi_write(" : [%m] : INFO : "); if(`DEBUG_INFO) dlsc_dpi_display
`define dlsc_verb if(`DEBUG_VERB) dlsc_dpi_write(" : [%m] : VERB : "); if(`DEBUG_VERB) dlsc_dpi_display

// macros for recording success or failure of a test
// (all invocations of these will be used for reporting final pass/fail when dlsc_finish is called)
`define dlsc_okay dlsc_dpi_okay; if(`DEBUG_OKAY) dlsc_dpi_write(" : [%m] : OKAY : "); if(`DEBUG_OKAY) dlsc_dpi_display
`define dlsc_error dlsc_dpi_error; dlsc_dpi_write(" : [%m] : *** ERROR *** : "); dlsc_dpi_display

// if condition is true, invokes dlsc_okay; otherwise, invokes dlsc_error
`define dlsc_assert(cond,msg) if(cond) begin `dlsc_okay(msg); end else begin `dlsc_error(msg); end if(0)

//`endif // `ifndef DLSC_COMMON_INCLUDED
`endif // `ifdef DLSC_SIMULATION

