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

`ifdef XILINX

    // DSP48A1 new for Spartan-6
    // (backward compatible with DSP48A, but not Virtex class DSP48s)
    `define DLSC_XILINX_DSP48A1     (DEVICE == "SPARTAN6")

    // DSP48A new for Spartan-3A DSP
    // (derived from DSP48, but not strictly compatible with it)
    `define DLSC_XILINX_DSP48A      (DEVICE == "SPARTAN3ADSP" || \
                                     `DLSC_XILINX_DSP48A1 )

    // DSP48E1 new for Virtex-6
    // (backward compatible with DSP48E)
    `define DLSC_XILINX_DSP48E1     (DEVICE == "VIRTEX6" || \
                                     DEVICE == "ARTIX7"  || \
                                     DEVICE == "KINTEX7" || \
                                     DEVICE == "VIRTEX7" )

    // DSP48E new for Virtex-5
    // (backward compatible with DSP48)
    `define DLSC_XILINX_DSP48E      (DEVICE == "VIRTEX5" || \
                                     `DLSC_XILINX_DSP48E1 )

    // DSP48 new for Virtex-4
    `define DLSC_XILINX_DSP48       (DEVICE == "VIRTEX4" || \
                                     `DLSC_XILINX_DSP48E )

`endif // XILINX

`endif // DLSC_DEVICES_INCLUDED

