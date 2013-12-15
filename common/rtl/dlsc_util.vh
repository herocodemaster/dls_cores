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

`include "dlsc_clog2.vh"

`define dlsc_min(x,y) ( ((x) < (y)) ? (x) : (y) )
`define dlsc_max(x,y) ( ((x) > (y)) ? (x) : (y) )
`define dlsc_abs(x) ( ((x) >= 0) ? (x) : (0-(x)) )

`ifndef ICARUS
    `define dlsc_static_assert(cond) initial begin if(!(cond)) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s' failed", $time, `"cond`"); $finish; end end
    `define dlsc_static_assert_eq(lhs,rhs)  initial begin if(!((lhs)==(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) == %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_neq(lhs,rhs) initial begin if(!((lhs)!=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) != %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_gt(lhs,rhs)  initial begin if(!((lhs)> (rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) >  %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_gte(lhs,rhs) initial begin if(!((lhs)>=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) >= %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_lt(lhs,rhs)  initial begin if(!((lhs)< (rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) <  %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_lte(lhs,rhs) initial begin if(!((lhs)<=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) <= %s (%0d)' failed", $time, `"lhs`", (lhs), `"rhs`", (rhs)); $finish; end end
    `define dlsc_static_assert_range(value,min,max) initial begin if(!(((value)>=(min))&&((value)<=(max)))) begin $display("%t : [%m] : *** ERROR *** : static assertion '%s (%0d) <= %s (%0d) <= %s (%0d)' failed", $time, `"min`", (min), `"value`", (value), `"max`", (max)); $finish; end end
`else
    // iverilog has some trouble with stringification
    `define dlsc_static_assert(cond) initial begin if(!(cond)) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_eq(lhs,rhs)  initial begin if(!((lhs)==(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_neq(lhs,rhs) initial begin if(!((lhs)!=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_gt(lhs,rhs)  initial begin if(!((lhs)> (rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_gte(lhs,rhs) initial begin if(!((lhs)>=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_lt(lhs,rhs)  initial begin if(!((lhs)< (rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_lte(lhs,rhs) initial begin if(!((lhs)<=(rhs))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
    `define dlsc_static_assert_range(value,min,max) initial begin if(!(((value)>=(min))&&((value)<=(max)))) begin $display("%t : [%m] : *** ERROR *** : static assertion failed", $time); $finish; end end
`endif

