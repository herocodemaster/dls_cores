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

`ifndef DLSC_DEVICES_INCLUDED
    `define DLSC_DEVICES_INCLUDED
    // allow local DEVICE parameter to be overridden by global `define
    `ifndef DLSC_DEVICE
        `define DLSC_DEVICE DEVICE
    `endif
`endif
    
/* verilator lint_off WIDTH */

`ifdef XILINX

    // ISE 13.4 parser throws a spurious syntax error on this line,
    // but XST has no problem with it.
    localparam DLSC_XILINX_DEVICE   = `DLSC_DEVICE;

    // DSP48A1 new for Spartan-6
    // (backward compatible with DSP48A, but not Virtex class DSP48s)
    localparam DLSC_XILINX_DSP48A1  = ( DLSC_XILINX_DEVICE == "SPARTAN6" );

    // DSP48A new for Spartan-3A DSP
    // (derived from DSP48, but not strictly compatible with it)
    localparam DLSC_XILINX_DSP48A   = ( DLSC_XILINX_DEVICE == "SPARTAN3ADSP" ||
                                        DLSC_XILINX_DSP48A1 );

    // DSP48E1 new for Virtex-6
    // (backward compatible with DSP48E)
    localparam DLSC_XILINX_DSP48E1  = ( DLSC_XILINX_DEVICE == "VIRTEX6" ||
                                        DLSC_XILINX_DEVICE == "ARTIX7"  ||
                                        DLSC_XILINX_DEVICE == "KINTEX7" ||
                                        DLSC_XILINX_DEVICE == "VIRTEX7" );

    // DSP48E new for Virtex-5
    // (backward compatible with DSP48)
    localparam DLSC_XILINX_DSP48E   = ( DLSC_XILINX_DEVICE == "VIRTEX5" ||
                                        DLSC_XILINX_DSP48E1 );

    // DSP48 new for Virtex-4
    localparam DLSC_XILINX_DSP48    = ( DLSC_XILINX_DEVICE == "VIRTEX4" ||
                                        DLSC_XILINX_DSP48E );

    // LUT6 present in Spartan 6 and Virtex 5+
    localparam DLSC_XILINX_LUT6     = ( DLSC_XILINX_DSP48A1 ||
                                        DLSC_XILINX_DSP48E );
    
    // DNA_PORT present in Spartan 3A[DSP], Spartan 6, and Virtex 6+
    localparam DLSC_XILINX_DNA_PORT = ( DLSC_XILINX_DSP48A ||
                                        DLSC_XILINX_DSP48E1 );

`endif // XILINX

/* verilator lint_on WIDTH */

